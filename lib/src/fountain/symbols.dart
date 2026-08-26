import 'dart:typed_data';

final class FountainSelection {
  const FountainSelection(this.indices, this.degree);

  final List<int> indices;
  final int degree;
}

FountainSelection selectSourceBlocks(
    int symbolId, int sourceCount, List<int> transferId) {
  if (symbolId < sourceCount) return FountainSelection([symbolId], 1);
  var state = (symbolId * 0x9e3779b1) & 0xffffffff;
  for (var i = 0; i < transferId.length; i++) {
    state = (state ^ (transferId[i] << ((i & 3) * 8))) & 0xffffffff;
  }

  int next() {
    state ^= (state << 13) & 0xffffffff;
    state ^= state >>> 17;
    state ^= (state << 5) & 0xffffffff;
    return state & 0xffffffff;
  }

  final maximumDegree = sourceCount < 8 ? sourceCount : 8;
  final degree = sourceCount == 1 ? 1 : 2 + (next() % (maximumDegree - 1));
  final selected = <int>{};
  while (selected.length < degree) {
    selected.add(next() % sourceCount);
  }
  final indices = selected.toList()..sort();
  return FountainSelection(indices, degree);
}

Uint8List xorBlocks(List<Uint8List> blocks, List<int> indices, int blockSize) {
  final output = Uint8List(blockSize);
  for (final index in indices) {
    final block = blocks[index];
    for (var i = 0; i < blockSize; i++) {
      output[i] ^= block[i];
    }
  }
  return output;
}
