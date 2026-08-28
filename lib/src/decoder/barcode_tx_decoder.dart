import 'dart:typed_data';

import '../exceptions/exceptions.dart';
import '../fountain/decoder.dart';
import '../models/batch.dart';
import '../models/options.dart';
import '../models/transaction.dart';
import '../protocol/bytes.dart';
import '../protocol/frame.dart';
import '../protocol/integrity.dart';
import '../protocol/serializer.dart';

final class BarcodeTxDecoderState {
  const BarcodeTxDecoderState({
    required this.progress,
    required this.isComplete,
    required this.receivedSymbols,
    required this.transferId,
    required this.accepted,
  });

  final double progress;
  final bool isComplete;
  final int receivedSymbols;
  final String? transferId;
  final bool accepted;
}

final class BarcodeTxDecoder {
  BarcodeTxDecoder({this.options = const BarcodeTxOptions()}) {
    options.validate();
  }

  final BarcodeTxOptions options;
  FountainDecoder? _fountain;
  Uint8List? _transferIdBytes;
  BarcodeTxBatch? _result;

  double get progress => _fountain?.progress ?? 0;
  bool get isComplete => _result != null;
  String? get transferId =>
      _transferIdBytes == null ? null : bytesToHex(_transferIdBytes!);
  int get receivedSymbols => _fountain?.receivedSymbols ?? 0;
  BarcodeTxBatch? get result => _result;
  List<BarcodeTxTransaction> get transactions =>
      _result?.transactions ??
      (throw StateError('BarcodeTX transfer is not complete.'));
  List<Map<String, Object>> get transactionMaps =>
      _result?.toMaps() ??
      (throw StateError('BarcodeTX transfer is not complete.'));

  BarcodeTxDecoderState addFrame(List<int> frameBytes) {
    if (frameBytes.length > options.maxQrPayloadBytes) {
      throw const BarcodeTxLimitException(
          'QR frame exceeds the configured maximum size.');
    }
    final frame = BarcodeTxFrame.parse(Uint8List.fromList(frameBytes), options);
    if (_transferIdBytes != null &&
        !constantTimeEquals(frame.transferIdBytes, _transferIdBytes!)) {
      return _state(accepted: false);
    }
    if (_fountain == null) {
      _transferIdBytes = Uint8List.fromList(frame.transferIdBytes);
      _fountain = FountainDecoder(
        payloadLength: frame.payloadLength,
        blockSize: frame.blockSize,
        sourceBlockCount: frame.sourceBlockCount,
        transferId: _transferIdBytes!,
        maxReceivedSymbols: options.maxReceivedSymbols,
      );
    } else if (frame.payloadLength != _fountain!.payloadLength ||
        frame.blockSize != _fountain!.blockSize ||
        frame.sourceBlockCount != _fountain!.sourceBlockCount) {
      throw const BarcodeTxProtocolException(
          'Inconsistent fountain metadata for transfer.');
    }

    _fountain!.add(frame);
    if (_fountain!.isComplete && _result == null) _finish(_fountain!.result!);
    return _state(accepted: true);
  }

  void _finish(Uint8List protectedPayload) {
    if (protectedPayload.length < 33) {
      throw const BarcodeTxProtocolException(
          'Protected batch payload is too short.');
    }
    final digestOffset = protectedPayload.length - 32;
    final batchBytes = Uint8List.sublistView(protectedPayload, 0, digestOffset);
    final suppliedDigest =
        Uint8List.sublistView(protectedPayload, digestOffset);
    final actualDigest = barcodeTxDigest(batchBytes);
    if (!constantTimeEquals(suppliedDigest, actualDigest)) {
      throw const BarcodeTxIntegrityException(
          'Reconstructed batch SHA-256 mismatch.');
    }
    if (!constantTimeEquals(_transferIdBytes!, actualDigest.sublist(0, 6))) {
      throw const BarcodeTxIntegrityException(
          'Reconstructed batch transfer ID mismatch.');
    }
    _result = BarcodeTxSerializer.deserialize(batchBytes, options);
  }

  BarcodeTxDecoderState _state({required bool accepted}) =>
      BarcodeTxDecoderState(
        progress: progress,
        isComplete: isComplete,
        receivedSymbols: receivedSymbols,
        transferId: transferId,
        accepted: accepted,
      );
}
