import 'dart:typed_data';

import '../exceptions/exceptions.dart';
import '../protocol/frame.dart';
import 'symbols.dart';

final class _Equation {
  _Equation(this.coefficients, this.value);
  BigInt coefficients;
  Uint8List value;
}

final class FountainDecoder {
  FountainDecoder({
    required this.payloadLength,
    required this.blockSize,
    required this.sourceBlockCount,
    required this.transferId,
    required this.maxReceivedSymbols,
  });

  final int payloadLength;
  final int blockSize;
  final int sourceBlockCount;
  final Uint8List transferId;
  final int maxReceivedSymbols;
  final Set<int> _symbolIds = {};
  final Map<int, _Equation> _rows = {};
  Uint8List? _result;

  int get receivedSymbols => _symbolIds.length;
  int get rank => _rows.length;
  double get progress => (rank / sourceBlockCount).clamp(0, 1);
  bool get isComplete => _result != null;
  Uint8List? get result =>
      _result == null ? null : Uint8List.fromList(_result!);

  void add(BarcodeTxFrame frame) {
    if (_result != null || !_symbolIds.add(frame.symbolId)) return;
    if (_symbolIds.length > maxReceivedSymbols) {
      throw BarcodeTxLimitException(
          'Received symbol count exceeds $maxReceivedSymbols.');
    }
    final selection =
        selectSourceBlocks(frame.symbolId, sourceBlockCount, transferId);
    if (selection.degree != frame.degree) {
      throw const BarcodeTxProtocolException(
          'Fountain symbol degree does not match its deterministic ID.');
    }
    var coefficients = BigInt.zero;
    for (final index in selection.indices) {
      coefficients |= BigInt.one << index;
    }
    var value = Uint8List.fromList(frame.symbol);

    while (coefficients != BigInt.zero) {
      final pivot = _lowestSetBit(coefficients);
      final existing = _rows[pivot];
      if (existing == null) {
        _rows[pivot] = _Equation(coefficients, value);
        break;
      }
      coefficients ^= existing.coefficients;
      value = _xor(value, existing.value);
    }
    if (coefficients == BigInt.zero && value.any((byte) => byte != 0)) {
      throw const BarcodeTxIntegrityException('Inconsistent fountain symbol.');
    }
    if (_rows.length == sourceBlockCount) _reconstruct();
  }

  void _reconstruct() {
    final solved = List<Uint8List?>.filled(sourceBlockCount, null);
    for (var pivot = sourceBlockCount - 1; pivot >= 0; pivot--) {
      final equation = _rows[pivot];
      if (equation == null) return;
      var value = Uint8List.fromList(equation.value);
      for (var index = pivot + 1; index < sourceBlockCount; index++) {
        if ((equation.coefficients & (BigInt.one << index)) != BigInt.zero) {
          value = _xor(value, solved[index]!);
        }
      }
      solved[pivot] = value;
    }
    final joined = Uint8List(sourceBlockCount * blockSize);
    for (var i = 0; i < solved.length; i++) {
      joined.setRange(i * blockSize, (i + 1) * blockSize, solved[i]!);
    }
    _result = Uint8List.sublistView(joined, 0, payloadLength);
  }

  static int _lowestSetBit(BigInt value) {
    var index = 0;
    while ((value & BigInt.one) == BigInt.zero) {
      value >>= 1;
      index++;
    }
    return index;
  }

  static Uint8List _xor(Uint8List a, Uint8List b) {
    final result = Uint8List(a.length);
    for (var i = 0; i < a.length; i++) {
      result[i] = a[i] ^ b[i];
    }
    return result;
  }
}
