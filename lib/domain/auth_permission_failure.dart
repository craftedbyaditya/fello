/// Thrown when the signed-in user lacks permission for an action.
class AuthPermissionFailure implements Exception {
  const AuthPermissionFailure([
    this.message = 'You do not have permission to do that.',
  ]);

  final String message;

  @override
  String toString() => message;
}
