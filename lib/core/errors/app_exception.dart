class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() =>
      'AppException: $message${code != null ? ' ($code)' : ''}';
}

class ServerException extends AppException {
  const ServerException(super.message, {super.code});
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

class LocationException extends AppException {
  const LocationException(super.message, {super.code});
}

class NotificationException extends AppException {
  const NotificationException(super.message, {super.code});
}
