/// Thrown when a public submission is blocked (rate limit, captcha, dedupe).
class SubmitGuardFailure implements Exception {
  const SubmitGuardFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
