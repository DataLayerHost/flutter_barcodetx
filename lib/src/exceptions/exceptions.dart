/// Base class for errors produced by BarcodeTX.
sealed class BarcodeTxException implements Exception {
  const BarcodeTxException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class BarcodeTxValidationException extends BarcodeTxException {
  const BarcodeTxValidationException(super.message);
}

final class BarcodeTxProtocolException extends BarcodeTxException {
  const BarcodeTxProtocolException(super.message);
}

final class BarcodeTxIntegrityException extends BarcodeTxException {
  const BarcodeTxIntegrityException(super.message);
}

final class BarcodeTxLimitException extends BarcodeTxException {
  const BarcodeTxLimitException(super.message);
}
