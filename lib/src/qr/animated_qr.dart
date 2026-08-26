import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../encoder/barcode_tx_encoder.dart';
import '../models/options.dart';

/// Displays the unbounded BarcodeTX fountain stream as binary QR symbols.
final class BarcodeTxAnimatedQr extends StatefulWidget {
  const BarcodeTxAnimatedQr({
    super.key,
    required this.transactions,
    this.options = const BarcodeTxOptions(),
    this.size,
    this.frameDuration,
    this.semanticsLabel = 'Animated BarcodeTX transaction QR code',
  });

  final Iterable<Object> transactions;
  final BarcodeTxOptions options;
  final double? size;
  final Duration? frameDuration;
  final String semanticsLabel;

  @override
  State<BarcodeTxAnimatedQr> createState() => _BarcodeTxAnimatedQrState();
}

final class _BarcodeTxAnimatedQrState extends State<BarcodeTxAnimatedQr> {
  late BarcodeTxEncoder _encoder;
  late Uint8List _bytes;
  Timer? _timer;
  var _symbolId = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(BarcodeTxAnimatedQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transactions != widget.transactions ||
        oldWidget.options != widget.options ||
        oldWidget.frameDuration != widget.frameDuration) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _symbolId = 0;
    _encoder = BarcodeTxEncoder(
        transactions: widget.transactions, options: widget.options);
    _bytes = _encoder.frameAt(_symbolId).bytes;
    _timer = Timer.periodic(
        widget.frameDuration ?? widget.options.frameDuration, (_) {
      if (!mounted) return;
      setState(() {
        _symbolId = _symbolId == 0xffffffff ? 0 : _symbolId + 1;
        _bytes = _encoder.frameAt(_symbolId).bytes;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qr = QrCode.fromUint8List(
      data: _bytes,
      errorCorrectLevel: widget.options.errorCorrection,
    );
    return QrImageView.withQr(
      qr: qr,
      size: widget.size ?? widget.options.qrSize,
      semanticsLabel: widget.semanticsLabel,
    );
  }
}
