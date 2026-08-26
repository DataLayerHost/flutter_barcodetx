import 'dart:typed_data';

import '../exceptions/exceptions.dart';
import '../protocol/frame.dart';
import 'symbols.dart';

final class FountainEncoder {
  FountainEncoder({
    required Uint8List payload,
    required this.transferId,
    required this.blockSize,
  }) : payload = Uint8List.fromList(payload) {
    if (blockSize <= 0) throw ArgumentError.value(blockSize, 'blockSize');
    sourceBlockCount = (payload.length + blockSize - 1) ~/ blockSize;
    if (sourceBlockCount == 0 || sourceBlockCount > 0xffff) {
      throw const BarcodeTxLimitException(
          'Invalid fountain source-block count.');
    }
    blocks = List.generate(sourceBlockCount, (index) {
      final block = Uint8List(blockSize);
      final start = index * blockSize;
      final end = start + blockSize < payload.length
          ? start + blockSize
          : payload.length;
      block.setRange(0, end - start, payload, start);
      return block;
    }, growable: false);
  }

  final Uint8List payload;
  final Uint8List transferId;
  final int blockSize;
  late final int sourceBlockCount;
  late final List<Uint8List> blocks;

  BarcodeTxFrame frame(int symbolId) {
    if (symbolId < 0 || symbolId > 0xffffffff) {
      throw RangeError.range(symbolId, 0, 0xffffffff, 'symbolId');
    }
    final selection =
        selectSourceBlocks(symbolId, sourceBlockCount, transferId);
    return BarcodeTxFrame(
      transferIdBytes: transferId,
      payloadLength: payload.length,
      blockSize: blockSize,
      sourceBlockCount: sourceBlockCount,
      symbolId: symbolId,
      degree: selection.degree,
      symbol: xorBlocks(blocks, selection.indices, blockSize),
    );
  }
}
