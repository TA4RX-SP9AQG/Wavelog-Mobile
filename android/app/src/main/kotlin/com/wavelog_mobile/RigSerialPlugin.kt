package com.wavelog_mobile

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import com.hoho.android.usbserial.util.SerialInputOutputManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * USB serial link to a radio's CAT port over USB OTG, built on
 * usb-serial-for-android (FTDI, CP210x, CH34x, PL2303 and CDC-ACM, which
 * covers the USB bridges built into current Icom, Yaesu, Kenwood and
 * Elecraft radios). The Dart side (lib/core/services/rig_serial_service.dart)
 * speaks the CAT protocol; this class only moves bytes.
 */
class RigSerialPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    SerialInputOutputManager.Listener {

    companion object {
        private const val ACTION_USB_PERMISSION = "com.wavelog_mobile.USB_PERMISSION"
    }

    private val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var port: UsbSerialPort? = null
    private var ioManager: SerialInputOutputManager? = null
    private var events: EventChannel.EventSink? = null
    private val channel = MethodChannel(messenger, "com.wavelog_mobile/rig_serial")

    private val detachReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            val device = intent.usbDevice() ?: return
            if (device.deviceId == port?.device?.deviceId) {
                close()
                events?.error("DETACHED", "USB device detached", null)
            }
        }
    }

    init {
        channel.setMethodCallHandler(this)
        EventChannel(messenger, "com.wavelog_mobile/rig_serial/data").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listDevices" -> result.success(findDrivers().map { d ->
                mapOf(
                    "deviceId" to d.device.deviceId,
                    "name" to (d.device.productName ?: d.device.deviceName),
                    "driver" to d.javaClass.simpleName.removeSuffix("SerialDriver"),
                    "vendorId" to d.device.vendorId,
                    "productId" to d.device.productId,
                    "hasPermission" to usbManager.hasPermission(d.device),
                )
            })
            "open" -> open(
                deviceId = call.argument<Int>("deviceId")!!,
                baudRate = call.argument<Int>("baudRate")!!,
                result = result,
            )
            "write" -> {
                val io = ioManager
                if (io == null) {
                    result.error("NOT_OPEN", "No serial port open", null)
                } else {
                    io.writeAsync(call.arguments as ByteArray)
                    result.success(null)
                }
            }
            "close" -> {
                close()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    // SerialInputOutputManager callbacks run on its own threads.
    override fun onNewData(data: ByteArray) {
        mainHandler.post { events?.success(data) }
    }

    override fun onRunError(e: Exception) {
        mainHandler.post {
            // close() stops the manager, which also ends a blocked read with
            // an error; only report failures of a port that is still open.
            if (port != null) {
                close()
                events?.error("IO_ERROR", e.message, null)
            }
        }
    }

    /**
     * A USB serial device was plugged in and Android handed it to the app
     * through the manifest's device filter, with permission granted; the
     * Dart side decides whether to connect (lib/providers/rig_provider.dart).
     */
    fun onDeviceAttached() {
        channel.invokeMethod("deviceAttached", null)
    }

    fun close() {
        if (port == null) return
        ioManager?.stop()
        ioManager = null
        try {
            port?.close()
        } catch (_: Exception) {
        }
        port = null
        try {
            context.unregisterReceiver(detachReceiver)
        } catch (_: IllegalArgumentException) {
        }
    }

    private fun findDrivers(): List<UsbSerialDriver> =
        UsbSerialProber.getDefaultProber().findAllDrivers(usbManager)

    private fun open(deviceId: Int, baudRate: Int, result: MethodChannel.Result) {
        close()
        val driver = findDrivers().firstOrNull { it.device.deviceId == deviceId }
        if (driver == null) {
            result.error("NOT_FOUND", "USB device not found", null)
            return
        }
        if (usbManager.hasPermission(driver.device)) {
            connect(driver, baudRate, result)
            return
        }
        requestPermission(driver.device) { granted ->
            if (granted) {
                connect(driver, baudRate, result)
            } else {
                result.error("PERMISSION_DENIED", "USB permission denied", null)
            }
        }
    }

    private fun requestPermission(device: UsbDevice, onResult: (Boolean) -> Unit) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                context.unregisterReceiver(this)
                onResult(intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false))
            }
        }
        ContextCompat.registerReceiver(
            context, receiver, IntentFilter(ACTION_USB_PERMISSION),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        // UsbManager fills in the grant extras, so the intent must be
        // mutable, and Android 14+ requires a mutable one to be explicit.
        val intent = Intent(ACTION_USB_PERMISSION).setPackage(context.packageName)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            PendingIntent.FLAG_MUTABLE else 0
        usbManager.requestPermission(
            device, PendingIntent.getBroadcast(context, 0, intent, flags),
        )
    }

    private fun connect(driver: UsbSerialDriver, baudRate: Int, result: MethodChannel.Result) {
        val connection = usbManager.openDevice(driver.device)
        if (connection == null) {
            result.error("OPEN_FAILED", "Could not open USB device", null)
            return
        }
        val p = driver.ports[0]
        try {
            p.open(connection)
            // Two stop bits: the Yaesu CAT protocols require them, and a
            // receiver set for one stop bit reads them as ordinary idle time.
            p.setParameters(baudRate, 8, UsbSerialPort.STOPBITS_2, UsbSerialPort.PARITY_NONE)
        } catch (e: Exception) {
            try {
                p.close()
            } catch (_: Exception) {
            }
            result.error("OPEN_FAILED", e.message, null)
            return
        }
        port = p
        ioManager = SerialInputOutputManager(p, this).also { it.start() }
        ContextCompat.registerReceiver(
            context, detachReceiver, IntentFilter(UsbManager.ACTION_USB_DEVICE_DETACHED),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        result.success(null)
    }

    private fun Intent.usbDevice(): UsbDevice? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
        else
            @Suppress("DEPRECATION") getParcelableExtra(UsbManager.EXTRA_DEVICE)
}
