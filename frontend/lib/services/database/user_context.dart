/// Holds the id of the signed-in user so repositories/sync always scope data to that user.
class UserContext {
  String? userId;
  String get requireUserId {
    final id = userId;
    if (id == null) throw StateError('No signed-in user');
    return id;
  }
}
