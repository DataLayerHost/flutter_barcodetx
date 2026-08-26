import 'package:flutter/material.dart';
import 'package:flutter_barcodetx/flutter_barcodetx.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() => runApp(const BarcodeTxExampleApp());

class BarcodeTxExampleApp extends StatelessWidget {
  const BarcodeTxExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ScannerPage());
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final decoder = BarcodeTxDecoder();
  Object? error;

  void _scan(BarcodeCapture capture) {
    if (decoder.isComplete) return;
    for (final barcode in capture.barcodes) {
      final bytes = switch (barcode.rawDecodedBytes) {
        DecodedBarcodeBytes(:final bytes) => bytes,
        DecodedVisionBarcodeBytes(:final bytes) => bytes,
        null => null,
      };
      if (bytes == null) continue;
      try {
        decoder.addFrame(bytes);
        error = null;
      } on BarcodeTxException catch (caught) {
        error = caught;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final complete = decoder.isComplete;
    return Scaffold(
      appBar: AppBar(title: const Text('BarcodeTX')),
      body: Column(
        children: [
          if (!complete) Expanded(child: MobileScanner(onDetect: _scan)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: complete ? _result() : _progress(),
          ),
        ],
      ),
    );
  }

  Widget _progress() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('SCANNING TRANSACTION'),
      Text('TRANSFER: ${decoder.transferId ?? "WAITING"}'),
      Text('PROGRESS: ${(decoder.progress * 100).round()}%'),
      Text('RECEIVED: ${decoder.receivedSymbols} SYMBOLS'),
      if (error != null) Text('IGNORED FRAME: $error'),
    ],
  );

  Widget _result() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${decoder.transactions.length} TRANSACTIONS RECEIVED'),
      for (final transaction in decoder.transactions) ...[
        const SizedBox(height: 12),
        Text(transaction.type),
        SelectableText(transaction.hex),
      ],
    ],
  );
}
