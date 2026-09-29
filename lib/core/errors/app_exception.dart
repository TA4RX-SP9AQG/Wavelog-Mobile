abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'İnternet bağlantısı yok'])
      : super(code: 'NETWORK_ERROR');
}

/// TLS handshake / certificate verification failure — distinct from a plain
/// NetworkException so callers can offer "continue without verification"
/// instead of a generic connection-failed message.
class SslException extends AppException {
  const SslException(
      [super.message = 'SSL sertifikası doğrulanamadı'])
      : super(code: 'SSL_ERROR');
}

class TimeoutException extends AppException {
  const TimeoutException([super.message = 'Bağlantı zaman aşımına uğradı'])
      : super(code: 'TIMEOUT');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Geçersiz API anahtarı'])
      : super(code: 'UNAUTHORIZED');
}

/// The API key is valid but lacks the scope the endpoint requires (HTTP
/// 403) — distinct from [UnauthorizedException] (401, the key itself is
/// wrong/expired) so the UI can tell the user what's actually missing
/// instead of "invalid API key".
class ForbiddenException extends AppException {
  ForbiddenException([String? serverMessage])
      : super(serverMessage ?? 'Bu işlem için API anahtarınızda yeterli izin yok',
            code: 'FORBIDDEN');
}

class ServerException extends AppException {
  final int? statusCode;
  const ServerException(super.message, {this.statusCode})
      : super(code: 'SERVER_ERROR');
}

class ParseException extends AppException {
  const ParseException([super.message = 'Yanıt ayrıştırılamadı'])
      : super(code: 'PARSE_ERROR');
}

class AdifParseException extends AppException {
  final int? lineNumber;
  const AdifParseException(super.message, {this.lineNumber})
      : super(code: 'ADIF_PARSE_ERROR');
}

class LocalStorageException extends AppException {
  const LocalStorageException([super.message = 'Yerel depolama hatası'])
      : super(code: 'LOCAL_STORAGE_ERROR');
}

class ValidationException extends AppException {
  const ValidationException(super.message)
      : super(code: 'VALIDATION_ERROR');
}
