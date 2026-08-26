import 'dart:typed_data';

import '../exceptions/exceptions.dart';
import '../models/options.dart';
import 'bytes.dart';
import 'crc32.dart';

final class BarcodeTxFrame {
  const BarcodeTxFrame({
    required this.transferIdBytes,
    required this.payloadLength,
    required this.blockSize,
    required this.sourceBlockCount,
    required this.symbolId,
    required this.degree,
    required this.symbol,
  });

  static const List<int> magic = [0x42, 0x58]; // BX
  static const int version = 1;

  final Uint8List transferIdBytes;
  final int payloadLength;
  final int blockSize;
  final int sourceBlockCount;
  final int symbolId;
  final int degree;
  final Uint8List symbol;

  Uint8List get bytes {
    final builder = BytesBuilder(copy: false)
      ..add(magic)
      ..addByte(version)
      ..addByte(0)
      ..add(transferIdBytes);
    writeUint32(builder, payloadLength);
    writeUint16(builder, blockSize);
    writeUint16(builder, sourceBlockCount);
    writeUint32(builder, symbolId);
    builder.addByte(degree);
    builder.add(symbol);
    final withoutCrc = builder.takeBytes();
    final output = BytesBuilder(copy: false)..add(withoutCrc);
    writeUint32(output, barcodeTxCrc32(withoutCrc));
    return output.takeBytes();
  }

  static BarcodeTxFrame parse(Uint8List bytes, BarcodeTxOptions options) {
    if (bytes.length < BarcodeTxOptions.frameOverhead ||
        bytes.length > options.maxQrPayloadBytes) {
      throw const BarcodeTxProtocolException('Invalid BarcodeTX frame size.');
    }
    if (bytes[0] != magic[0] || bytes[1] != magic[1]) {
      throw const BarcodeTxProtocolException('Not a BarcodeTX frame.');
    }
    if (bytes[2] != version) {
      throw BarcodeTxProtocolException(
          'Unsupported frame version ${bytes[2]}.');
    }
    if (bytes[3] != 0) {
      throw const BarcodeTxProtocolException('Unsupported frame flags.');
    }
    final expectedCrc = readUint32(bytes, bytes.length - 4);
    final actualCrc =
        barcodeTxCrc32(Uint8List.sublistView(bytes, 0, bytes.length - 4));
    if (actualCrc != expectedCrc) {
      throw const BarcodeTxIntegrityException('Frame CRC-32 mismatch.');
    }

    final payloadLength = readUint32(bytes, 10);
    final blockSize = readUint16(bytes, 14);
    final sourceCount = readUint16(bytes, 16);
    final symbolId = readUint32(bytes, 18);
    final degree = bytes[22];
    if (payloadLength == 0 || payloadLength > options.maxBatchBytes + 32) {
      throw const BarcodeTxLimitException(
          'Frame declares an excessive payload length.');
    }
    if (blockSize == 0 ||
        blockSize > options.sourceBlockBytes ||
        bytes.length != BarcodeTxOptions.frameOverhead + blockSize) {
      throw const BarcodeTxProtocolException('Invalid fountain block size.');
    }
    final expectedCount = (payloadLength + blockSize - 1) ~/ blockSize;
    if (sourceCount == 0 ||
        sourceCount != expectedCount ||
        sourceCount > 0xffff) {
      throw const BarcodeTxProtocolException(
          'Invalid fountain source-block count.');
    }
    if (degree == 0 || degree > sourceCount || degree > 8) {
      throw const BarcodeTxProtocolException('Invalid fountain symbol degree.');
    }
    return BarcodeTxFrame(
      transferIdBytes: Uint8List.sublistView(bytes, 4, 10),
      payloadLength: payloadLength,
      blockSize: blockSize,
      sourceBlockCount: sourceCount,
      symbolId: symbolId,
      degree: degree,
      symbol: Uint8List.sublistView(bytes, 23, bytes.length - 4),
    );
  }
}
