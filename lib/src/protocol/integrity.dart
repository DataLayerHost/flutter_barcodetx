import 'dart:typed_data';

import 'package:crypto/crypto.dart';

Uint8List barcodeTxDigest(List<int> bytes) =>
    Uint8List.fromList(sha256.convert(bytes).bytes);

Uint8List barcodeTxTransferId(List<int> canonicalBatch) =>
    Uint8List.sublistView(barcodeTxDigest(canonicalBatch), 0, 6);
