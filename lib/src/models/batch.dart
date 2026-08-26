import 'transaction.dart';

final class BarcodeTxBatch {
  BarcodeTxBatch(
      {this.version = 1, required List<BarcodeTxTransaction> transactions})
      : transactions = List.unmodifiable(transactions);

  final int version;
  final List<BarcodeTxTransaction> transactions;

  List<Map<String, String>> toMaps() => transactions
      .map((transaction) => transaction.toMap())
      .toList(growable: false);
}
