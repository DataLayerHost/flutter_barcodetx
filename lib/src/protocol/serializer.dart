import 'dart:convert';
import 'dart:typed_data';

import '../exceptions/exceptions.dart';
import '../models/batch.dart';
import '../models/options.dart';
import '../models/transaction.dart';
import 'bytes.dart';

final class BarcodeTxSerializer {
  static const List<int> magic = [0x42, 0x54, 0x58, 0x42]; // BTXB
  static const int version = 1;

  static Uint8List serialize(BarcodeTxBatch batch, BarcodeTxOptions options) {
    options.validate();
    if (batch.version != version) {
      throw BarcodeTxProtocolException(
          'Unsupported batch version ${batch.version}.');
    }
    if (batch.transactions.isEmpty) {
      throw const BarcodeTxValidationException(
          'A batch requires at least one transaction.');
    }
    if (batch.transactions.length > options.maxTransactions ||
        batch.transactions.length > 0xffff) {
      throw BarcodeTxLimitException(
          'Transaction count exceeds ${options.maxTransactions}.');
    }
    final builder = BytesBuilder(copy: false)
      ..add(magic)
      ..addByte(version);
    writeUint16(builder, batch.transactions.length);
    for (final transaction in batch.transactions) {
      final type = ascii.encode(transaction.type);
      final payload = transaction.bytes;
      if (type.length > options.maxTypeBytes || type.length > 0xff) {
        throw BarcodeTxLimitException(
            'Transaction type exceeds ${options.maxTypeBytes} bytes.');
      }
      if (payload.length > options.maxTransactionBytes) {
        throw BarcodeTxLimitException(
            'Transaction exceeds ${options.maxTransactionBytes} bytes.');
      }
      builder.addByte(type.length);
      builder.add(type);
      writeUint32(builder, payload.length);
      builder.add(payload);
    }
    final result = builder.takeBytes();
    if (result.length > options.maxBatchBytes) {
      throw BarcodeTxLimitException(
          'Serialized batch exceeds ${options.maxBatchBytes} bytes.');
    }
    return result;
  }

  static BarcodeTxBatch deserialize(Uint8List bytes, BarcodeTxOptions options) {
    if (bytes.length < 7 || bytes.length > options.maxBatchBytes) {
      throw const BarcodeTxProtocolException('Invalid batch length.');
    }
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) {
        throw const BarcodeTxProtocolException('Invalid batch magic.');
      }
    }
    final batchVersion = bytes[4];
    if (batchVersion != version) {
      throw BarcodeTxProtocolException(
          'Unsupported batch version $batchVersion.');
    }
    final count = readUint16(bytes, 5);
    if (count == 0 || count > options.maxTransactions) {
      throw const BarcodeTxProtocolException('Invalid transaction count.');
    }
    var offset = 7;
    final transactions = <BarcodeTxTransaction>[];
    for (var index = 0; index < count; index++) {
      if (offset >= bytes.length) {
        throw const BarcodeTxProtocolException('Truncated transaction type.');
      }
      final typeLength = bytes[offset++];
      if (typeLength == 0 ||
          typeLength > options.maxTypeBytes ||
          offset + typeLength + 4 > bytes.length) {
        throw const BarcodeTxProtocolException(
            'Invalid transaction type length.');
      }
      String type;
      try {
        type = ascii.decode(bytes.sublist(offset, offset + typeLength));
      } on FormatException {
        throw const BarcodeTxProtocolException(
            'Transaction type is not ASCII.');
      }
      offset += typeLength;
      final payloadLength = readUint32(bytes, offset);
      offset += 4;
      if (payloadLength == 0 ||
          payloadLength > options.maxTransactionBytes ||
          payloadLength > bytes.length - offset) {
        throw const BarcodeTxProtocolException(
            'Invalid transaction payload length.');
      }
      transactions.add(BarcodeTxTransaction.fromBytes(
          type, bytes.sublist(offset, offset + payloadLength)));
      offset += payloadLength;
    }
    if (offset != bytes.length) {
      throw const BarcodeTxProtocolException('Trailing bytes after batch.');
    }
    return BarcodeTxBatch(version: batchVersion, transactions: transactions);
  }
}
