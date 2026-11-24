/// Simple callback hook the network layer uses to notify the app that the
/// session is no longer valid (401 received) so the router can redirect to
/// login and the token can be cleared. Kept decoupled from Riverpod so the
/// Dio client has no circular dependency on providers.
class AuthSessionNotifier {
  AuthSessionNotifier._();
  static final AuthSessionNotifier instance = AuthSessionNotifier._();

  void Function()? onUnauthorized;

  void notifyUnauthorized() {
    onUnauthorized?.call();
  }
}
