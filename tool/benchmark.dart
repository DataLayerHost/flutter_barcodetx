import 'dart:math';

// ignore_for_file: avoid_print

import 'package:flutter_barcodetx/src/decoder/barcode_tx_decoder.dart';
import 'package:flutter_barcodetx/src/encoder/barcode_tx_encoder.dart';
import 'package:flutter_barcodetx/src/models/transaction.dart';

void main() {
  for (final size in [250, 500, 1024, 5 * 1024, 10 * 1024]) {
    final random = Random(size);
    final bytes = List<int>.generate(size, (_) => random.nextInt(256));
    final transaction = BarcodeTxTransaction.fromBytes('BENCH', bytes);

    final encodeWatch = Stopwatch()..start();
    final encoder = BarcodeTxEncoder(transactions: [transaction]);
    final firstFrameSize = encoder.frameAt(0).bytes.length;
    encodeWatch.stop();

    final decoder = BarcodeTxDecoder();
    final decodeWatch = Stopwatch()..start();
    var generated = 0;
    var accepted = 0;
    while (!decoder.isComplete) {
      // Simulate losing every fifth displayed symbol.
      final id = generated++;
      if (id % 5 == 0) continue;
      decoder.addFrame(encoder.frameAt(id).bytes);
      accepted++;
    }
    decodeWatch.stop();

    final overhead =
        (accepted - encoder.sourceBlockCount) / encoder.sourceBlockCount * 100;
    print([
      'input=$size B',
      'serialized=${encoder.serializedBatch.length} B',
      'blocks=${encoder.sourceBlockCount}',
      'qrFrame=$firstFrameSize B',
      'accepted=$accepted',
      'generated=$generated',
      'fountainOverhead=${overhead.toStringAsFixed(1)}%',
      'encode=${encodeWatch.elapsedMicroseconds} us',
      'decode=${decodeWatch.elapsedMicroseconds} us',
    ].join(' | '));
  }
}
