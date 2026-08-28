final class BarcodeTxOptions {
  const BarcodeTxOptions({
    this.qrSize = 320,
    this.frameDuration = const Duration(milliseconds: 150),
    this.errorCorrection = 0,
    this.maxQrPayloadBytes = 800,
    this.maxBatchBytes = 1024 * 1024,
    this.maxTransactionBytes = 512 * 1024,
    this.maxTransactions = 256,
    this.maxReceivedSymbols = 8192,
  });

  final double qrSize;
  final Duration frameDuration;
  final int errorCorrection;
  final int maxQrPayloadBytes;
  final int maxBatchBytes;
  final int maxTransactionBytes;
  final int maxTransactions;
  final int maxReceivedSymbols;

  static const int frameOverhead = 27;

  int get sourceBlockBytes => maxQrPayloadBytes - frameOverhead;

  void validate() {
    if (qrSize <= 0 || frameDuration <= Duration.zero) {
      throw ArgumentError('QR size and frame duration must be positive.');
    }
    const qrByteCapacities = <int, int>{0: 2331, 1: 2953, 2: 1273, 3: 1663};
    final qrCapacity = qrByteCapacities[errorCorrection];
    if (qrCapacity == null) {
      throw ArgumentError.value(errorCorrection, 'errorCorrection',
          'Expected a qr package error-correction constant.');
    }
    if (maxQrPayloadBytes <= frameOverhead || maxQrPayloadBytes > qrCapacity) {
      throw ArgumentError(
          'maxQrPayloadBytes must be 28..$qrCapacity at the selected QR error-correction level.');
    }
    if (maxBatchBytes <= 0 ||
        maxBatchBytes > 0xffffffff - 32 ||
        maxTransactionBytes <= 0 ||
        maxTransactionBytes > 0xffffffff ||
        maxTransactions <= 0 ||
        maxTransactions > 0xffff ||
        maxReceivedSymbols <= 0) {
      throw ArgumentError(
          'Protocol limits are outside their wire-format ranges.');
    }
  }
}
