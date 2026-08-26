import 'dart:async';
import 'dart:typed_data';

import '../fountain/encoder.dart';
import '../models/batch.dart';
import '../models/options.dart';
import '../models/transaction.dart';
import '../protocol/bytes.dart';
import '../protocol/frame.dart';
import '../protocol/integrity.dart';
import '../protocol/serializer.dart';

final class BarcodeTxEncoder {
  BarcodeTxEncoder({
    required Iterable<Object> transactions,
    this.options = const BarcodeTxOptions(),
  }) : batch =
            BarcodeTxBatch(transactions: _normalizeTransactions(transactions)) {
    options.validate();
    serializedBatch = BarcodeTxSerializer.serialize(batch, options);
    final digest = barcodeTxDigest(serializedBatch);
    transferIdBytes = Uint8List.sublistView(digest, 0, 6);
    final protectedPayload = Uint8List(serializedBatch.length + digest.length)
      ..setRange(0, serializedBatch.length, serializedBatch)
      ..setRange(serializedBatch.length, serializedBatch.length + digest.length,
          digest);
    _fountain = FountainEncoder(
      payload: protectedPayload,
      transferId: transferIdBytes,
      blockSize: options.sourceBlockBytes,
    );
  }

  final BarcodeTxOptions options;
  final BarcodeTxBatch batch;
  late final Uint8List serializedBatch;
  late final Uint8List transferIdBytes;
  late final FountainEncoder _fountain;

  String get transferId => bytesToHex(transferIdBytes);
  int get sourceBlockCount => _fountain.sourceBlockCount;
  int get blockSize => _fountain.blockSize;

  BarcodeTxFrame frameAt(int symbolId) => _fountain.frame(symbolId);

  Stream<BarcodeTxFrame> get frames async* {
    var symbolId = 0;
    while (true) {
      yield frameAt(symbolId);
      symbolId = symbolId == 0xffffffff ? 0 : symbolId + 1;
      await Future<void>.delayed(options.frameDuration);
    }
  }

  static List<BarcodeTxTransaction> _normalizeTransactions(
      Iterable<Object> values) {
    return values.map((value) {
      if (value is BarcodeTxTransaction) {
        return value;
      }
      if (value is Map<String, Object?>) {
        return BarcodeTxTransaction.fromMap(value);
      }
      if (value is Map) {
        return BarcodeTxTransaction.fromMap(value.cast<String, Object?>());
      }
      throw ArgumentError.value(value, 'transactions',
          'Expected BarcodeTxTransaction or a transaction map.');
    }).toList(growable: false);
  }
}
