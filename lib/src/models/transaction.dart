import 'dart:typed_data';

import '../exceptions/exceptions.dart';

/// An opaque, already-signed blockchain transaction and its caller-supplied type.
final class BarcodeTxTransaction {
  BarcodeTxTransaction({required String type, required String hex})
      : type = _normalizeType(type),
        hex = _normalizeHex(hex);

  final String type;
  final String hex;

  Uint8List get bytes {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  Map<String, String> toMap() => {'type': type, 'hex': hex};

  factory BarcodeTxTransaction.fromMap(Map<String, Object?> value) {
    final type = value['type'];
    final hex = value['hex'];
    if (type is! String || hex is! String) {
      throw const BarcodeTxValidationException(
        'Transaction maps require String "type" and "hex" values.',
      );
    }
    return BarcodeTxTransaction(type: type, hex: hex);
  }

  static BarcodeTxTransaction fromBytes(String type, List<int> bytes) =>
      BarcodeTxTransaction(
        type: type,
        hex: bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      );

  static String _normalizeType(String value) {
    final normalized = value.toUpperCase();
    if (normalized.isEmpty) {
      throw const BarcodeTxValidationException('Transaction type is empty.');
    }
    if (!RegExp(r'^[A-Z0-9][A-Z0-9._+-]*$').hasMatch(normalized)) {
      throw const BarcodeTxValidationException(
        'Transaction type must be an ASCII identifier containing only A-Z, 0-9, dot, underscore, plus, or hyphen.',
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
      other is BarcodeTxTransaction && other.type == type && other.hex == hex;

  @override
  int get hashCode => Object.hash(type, hex);

  @override
  String toString() => 'BarcodeTxTransaction(type: $type, hex: $hex)';
}
