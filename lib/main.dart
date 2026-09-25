import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/services/chat_notification_service.dart';
import 'core/services/intent_handler.dart';
import 'data/models/qso_model.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await ChatNotificationService.handleData(message.data);
}

/// Bildirim izni istemi (Android 13+ sistem popup'ı gösterir ve kullanıcının
/// cevabını bekler) ve topic aboneliği (ağ round-trip'i) — ilk karenin
/// çizilmesini bloklamaması için runApp()'tan SONRA, awaitlenmeden
/// çalıştırılır. Daha önce main()'in içinde, runApp()'tan önce await
/// ediliyordu; ilk kurulumda kullanıcı sistem popup'ını hemen fark
/// etmezse veya bağlantı yavaşsa, uygulamanın kendi splash animasyonu
/// bile görünmeden ekran donmuş gibi kalıyordu.
Future<void> _deferredFirebaseMessagingSetup() async {
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance.subscribeToTopic('new_activations');
  } catch (_) {
    // Bildirim izni reddedilmesi veya ağ hatası — sessizce yut, uygulama
    // bildirimler olmadan da tam işlevsel.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen(
    (message) => ChatNotificationService.handleData(message.data),
  );
  await ChatNotificationService.initialize();

  await initializeDateFormatting();

  await Hive.initFlutter();
  Hive.registerAdapter(QsoModelAdapter());
  await Hive.openBox<QsoModel>('qso_cache');

  IntentHandler.initialize();

  runApp(
    const ProviderScope(
      child: WavelogMobileApp(),
    ),
  );

  // Splash ekranı zaten görünür durumda — bildirim izni/abonelik artık
  // arayüzü bloklamadan arka planda tamamlanabilir.
  unawaited(_deferredFirebaseMessagingSetup());
}
