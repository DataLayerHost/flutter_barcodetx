import 'dart:typed_data';

int readUint16(Uint8List bytes, int offset) =>
    (ByteData.sublistView(bytes, offset, offset + 2)).getUint16(0);

int readUint32(Uint8List bytes, int offset) =>
    (ByteData.sublistView(bytes, offset, offset + 4)).getUint32(0);

void writeUint16(BytesBuilder builder, int value) {
  final bytes = ByteData(2)..setUint16(0, value);
  builder.add(bytes.buffer.asUint8List());
}

void writeUint32(BytesBuilder builder, int value) {
  final bytes = ByteData(4)..setUint32(0, value);
  builder.add(bytes.buffer.asUint8List());
}

bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}

String bytesToHex(List<int> bytes) => bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join()
    .toUpperCase();
