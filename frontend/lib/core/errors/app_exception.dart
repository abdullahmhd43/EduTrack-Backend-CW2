/// Typed errors so ViewModels/UI can react without parsing strings.
class AppException implements Exception {
  final String message;
  final int? statusCode;
  const AppException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// No connectivity / server unreachable / timeout.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Cannot reach the server. Check your connection.']);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Session expired. Please log in again.']) : super(statusCode: 401);
}

class ValidationException extends AppException {
  final Map<String, String> fieldErrors;
  const ValidationException(super.message, {this.fieldErrors = const {}}) : super(statusCode: 400);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Record not found on the server.']) : super(statusCode: 404);
}

/// Server copy is newer than the version the client edited (HTTP 409).
class ConflictException extends AppException {
  final Map<String, dynamic>? serverVersion;
  const ConflictException(super.message, {this.serverVersion}) : super(statusCode: 409);
}

class ServerException extends AppException {
  const ServerException([super.message = 'Server error. Please try again later.', int? code]) : super(statusCode: code);
}
