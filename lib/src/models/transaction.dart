import 'dart:typed_data';

import '../exceptions/exceptions.dart';

/// An opaque, already-signed transaction with its blockchain and network.
final class BarcodeTxTransaction {
  BarcodeTxTransaction({
    required String blockchain,
    this.networkId,
    required String hex,
  })  : blockchain = _normalizeBlockchain(blockchain),
        hex = _normalizeHex(hex) {
    if (networkId != null && (networkId! < 0 || networkId! > 0xffffffff)) {
      throw const BarcodeTxValidationException(
        'Network ID must be an unsigned 32-bit integer.',
      );
    }
  }

  final String blockchain;
  final int? networkId;
  final String hex;

  Uint8List get bytes {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  Map<String, Object> toMap() => {
        'blockchain': blockchain,
        if (networkId != null) 'networkId': networkId!,
        'hex': hex,
      };

  factory BarcodeTxTransaction.fromMap(Map<String, Object?> value) {
    final blockchain = value['blockchain'];
    final networkId = value['networkId'];
    final hex = value['hex'];
    if (blockchain is! String ||
        (networkId != null && networkId is! int) ||
        hex is! String) {
      throw const BarcodeTxValidationException(
        'Transaction maps require String "blockchain" and "hex" values and an optional integer "networkId".',
      );
    }
    return BarcodeTxTransaction(
      blockchain: blockchain,
      networkId: networkId as int?,
      hex: hex,
    );
  }

  static BarcodeTxTransaction fromBytes(
    String blockchain,
    List<int> bytes, {
    int? networkId,
  }) =>
      BarcodeTxTransaction(
        blockchain: blockchain,
        networkId: networkId,
        hex: bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      );

  static String _normalizeBlockchain(String value) {
    final normalized = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalized)) {
      throw const BarcodeTxValidationException(
        'Blockchain must be a three-letter ASCII code.',
      );
    }
    return normalized;
  }

  static String _normalizeHex(String value) {
    var normalized = value;
    if (normalized.startsWith('0x') || normalized.startsWith('0X')) {
      normalized = normalized.substring(2);
    }
    if (normalized.isEmpty) {
      throw const BarcodeTxValidationException('Transaction hex is empty.');
    }
    if (normalized.length.isOdd) {
      throw const BarcodeTxValidationException(
        'Transaction hex must contain an even number of characters.',
      );
    }
    if (!RegExp(r'^[0-9A-Fa-f]+$').hasMatch(normalized)) {
      throw const BarcodeTxValidationException(
        'Transaction hex contains a non-hexadecimal character.',
      );
    }
    return normalized.toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      other is BarcodeTxTransaction &&
      other.blockchain == blockchain &&
      other.networkId == networkId &&
      other.hex == hex;

  @override
  int get hashCode => Object.hash(blockchain, networkId, hex);

  @override
  String toString() =>
      'BarcodeTxTransaction(blockchain: $blockchain, networkId: $networkId, hex: $hex)';
}
