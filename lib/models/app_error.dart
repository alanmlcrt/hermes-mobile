/// Enveloppe locale ; ne conserve jamais le message brut du serveur.
class AppError implements Exception {
  const AppError(this.code, {this.retryable = false, this.operationKey});
  final String code;
  final bool retryable;
  final String? operationKey;
  @override
  String toString() => code;
}
