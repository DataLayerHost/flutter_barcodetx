import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_barcodetx/flutter_barcodetx.dart';
import 'package:flutter_barcodetx/src/protocol/serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalization and validation', () {
    test('normalizes blockchain, hex, and optional prefix', () {
      final transaction =
          BarcodeTxTransaction(blockchain: 'xcb', hex: '0xabcD');
      expect(transaction.blockchain, 'XCB');
      expect(transaction.hex, 'ABCD');
      expect(transaction.bytes, [0xab, 0xcd]);
      expect(transaction.toMap(), {'blockchain': 'XCB', 'hex': 'ABCD'});
    });

    test('accepts map input', () {
      final encoder = BarcodeTxEncoder(transactions: [
        {'blockchain': 'btc', 'hex': '02000000'},
      ]);
      expect(encoder.batch.transactions.single.blockchain, 'BTC');
    });

    test('rejects malformed inputs with typed exceptions', () {
      expect(() => BarcodeTxTransaction(blockchain: '', hex: 'AA'),
          throwsA(isA<BarcodeTxValidationException>()));
      expect(() => BarcodeTxTransaction(blockchain: 'ETH!', hex: 'AA'),
          throwsA(isA<BarcodeTxValidationException>()));
      expect(() => BarcodeTxTransaction(blockchain: 'ETH', hex: ''),
          throwsA(isA<BarcodeTxValidationException>()));
      expect(() => BarcodeTxTransaction(blockchain: 'ETH', hex: 'GG'),
          throwsA(isA<BarcodeTxValidationException>()));
      expect(() => BarcodeTxTransaction(blockchain: 'ETH', hex: 'ABC'),
          throwsA(isA<BarcodeTxValidationException>()));
    });
  });

  group('round trips', () {
    test('single XCB transaction', () {
      _roundTrip([BarcodeTxTransaction(blockchain: 'XCB', hex: '0xABCD')]);
    });

    test('single ETH transaction', () {
      _roundTrip([BarcodeTxTransaction(blockchain: 'eth', hex: 'f86c0185')]);
    });

    test('mixed transactions preserve order', () {
      _roundTrip([
        BarcodeTxTransaction(blockchain: 'xcb', hex: 'AABB'),
        BarcodeTxTransaction(blockchain: 'btc', hex: '02000000'),
        BarcodeTxTransaction(blockchain: 'sol', hex: '010203040506'),
      ]);
    });

    test('optional network ID survives round trip', () {
      _roundTrip([
        BarcodeTxTransaction(
            blockchain: 'ETH', networkId: 137, hex: 'F86C0185'),
      ]);
    });

    test('large transaction needs and recovers from many symbols', () {
      final hex = List.generate(
              5000, (index) => (index & 0xff).toRadixString(16).padLeft(2, '0'))
          .join();
      final options = const BarcodeTxOptions(maxQrPayloadBytes: 96);
      final transaction = BarcodeTxTransaction(blockchain: 'DOG', hex: hex);
      final encoder =
          BarcodeTxEncoder(transactions: [transaction], options: options);
      expect(encoder.sourceBlockCount, greaterThan(50));
      final decoder = BarcodeTxDecoder(options: options);
      for (var id = 0; !decoder.isComplete && id < 1000; id++) {
        decoder.addFrame(encoder.frameAt(id).bytes);
      }
      expect(decoder.isComplete, isTrue);
      expect(decoder.transactions, [transaction]);
    });

    test('random drops, shuffle, duplicates, and parity recover', () {
      for (var iteration = 0; iteration < 10; iteration++) {
        final random = Random(0x425458 + iteration);
        final bytes = List<int>.generate(1400, (_) => random.nextInt(256));
        final transaction = BarcodeTxTransaction.fromBytes('ABC', bytes);
        final options = const BarcodeTxOptions(maxQrPayloadBytes: 96);
        final encoder =
            BarcodeTxEncoder(transactions: [transaction], options: options);
        final ids = <int>[];
        for (var id = 0; id < encoder.sourceBlockCount * 4; id++) {
          if (random.nextDouble() >= 0.35) ids.add(id);
        }
        ids
          ..addAll(ids.take(5))
          ..shuffle(random);
        final decoder = BarcodeTxDecoder(options: options);
        for (final id in ids) {
          decoder.addFrame(encoder.frameAt(id).bytes);
          if (decoder.isComplete) break;
        }
        expect(decoder.isComplete, isTrue, reason: 'iteration $iteration');
        expect(decoder.transactions.single, transaction);
      }
    });
  });

  group('protocol and integrity', () {
    test('serialization and transfer ID are deterministic', () {
      final transactions = [
        BarcodeTxTransaction(blockchain: 'xcb', hex: 'AABBCCDD')
      ];
      final first = BarcodeTxEncoder(transactions: transactions);
      final second = BarcodeTxEncoder(transactions: transactions);
      expect(first.serializedBatch, second.serializedBatch);
      expect(first.transferId, second.transferId);
      expect(first.frameAt(8).bytes, second.frameAt(8).bytes);
    });

    test('different batches have different IDs', () {
      final first = BarcodeTxEncoder(
          transactions: [BarcodeTxTransaction(blockchain: 'XCB', hex: 'AA')]);
      final second = BarcodeTxEncoder(
          transactions: [BarcodeTxTransaction(blockchain: 'XCB', hex: 'AB')]);
      expect(first.transferId, isNot(second.transferId));
    });

    test('mixed transfers are ignored after the session is selected', () {
      final first = BarcodeTxEncoder(transactions: [
        BarcodeTxTransaction(
            blockchain: 'XCB', hex: List.filled(1000, 'AA').join())
      ]);
      final second = BarcodeTxEncoder(transactions: [
        BarcodeTxTransaction(
            blockchain: 'BTC', hex: List.filled(1000, 'BB').join())
      ]);
      final decoder = BarcodeTxDecoder();
      expect(decoder.addFrame(first.frameAt(0).bytes).accepted, isTrue);
      expect(decoder.addFrame(second.frameAt(0).bytes).accepted, isFalse);
      for (var id = 1; !decoder.isComplete; id++) {
        decoder.addFrame(first.frameAt(id).bytes);
      }
      expect(decoder.transactions.single.blockchain, 'XCB');
    });

    test('rejects corrupted frame', () {
      final encoder = BarcodeTxEncoder(
          transactions: [BarcodeTxTransaction(blockchain: 'XCB', hex: 'AABB')]);
      final bytes = Uint8List.fromList(encoder.frameAt(0).bytes)..[23] ^= 1;
      expect(() => BarcodeTxDecoder().addFrame(bytes),
          throwsA(isA<BarcodeTxIntegrityException>()));
    });

    test('rejects corrupted reconstructed payload', () {
      final encoder = BarcodeTxEncoder(
        transactions: [
          BarcodeTxTransaction(
              blockchain: 'XCB', hex: List.filled(100, 'AA').join())
        ],
        options: const BarcodeTxOptions(maxQrPayloadBytes: 64),
      );
      final decoder = BarcodeTxDecoder(options: encoder.options);
      for (var id = 0; id < encoder.sourceBlockCount; id++) {
        var frame = encoder.frameAt(id);
        if (id == 0) {
          final symbol = Uint8List.fromList(frame.symbol)..[0] ^= 1;
          frame = BarcodeTxFrame(
            transferIdBytes: frame.transferIdBytes,
            payloadLength: frame.payloadLength,
            blockSize: frame.blockSize,
            sourceBlockCount: frame.sourceBlockCount,
            symbolId: frame.symbolId,
            degree: frame.degree,
            symbol: symbol,
          );
        }
        if (id == encoder.sourceBlockCount - 1) {
          expect(() => decoder.addFrame(frame.bytes),
              throwsA(isA<BarcodeTxIntegrityException>()));
        } else {
          decoder.addFrame(frame.bytes);
        }
      }
    });

    test('rejects unknown frame version', () {
      final encoder = BarcodeTxEncoder(
          transactions: [BarcodeTxTransaction(blockchain: 'XCB', hex: 'AA')]);
      final bytes = Uint8List.fromList(encoder.frameAt(0).bytes)..[2] = 99;
      expect(() => BarcodeTxDecoder().addFrame(bytes),
          throwsA(isA<BarcodeTxProtocolException>()));
    });

    test('rejects oversized declared payload before allocation', () {
      final options = const BarcodeTxOptions(maxBatchBytes: 100);
      final frame = BarcodeTxFrame(
        transferIdBytes: Uint8List(6),
        payloadLength: 133,
        blockSize: 1,
        sourceBlockCount: 133,
        symbolId: 0,
        degree: 1,
        symbol: Uint8List(1),
      );
      expect(() => BarcodeTxDecoder(options: options).addFrame(frame.bytes),
          throwsA(isA<BarcodeTxLimitException>()));
    });

    test('batch deserializer rejects oversized internal length', () {
      final bytes = Uint8List.fromList([
        ...BarcodeTxSerializer.magic,
        1,
        0,
        1,
        88,
        67,
        66,
        0,
        0x7f,
        0xff,
        0xff,
        0xff
      ]);
      expect(
          () =>
              BarcodeTxSerializer.deserialize(bytes, const BarcodeTxOptions()),
          throwsA(isA<BarcodeTxProtocolException>()));
    });
  });
}

void _roundTrip(List<BarcodeTxTransaction> transactions) {
  final encoder = BarcodeTxEncoder(transactions: transactions);
  final decoder = BarcodeTxDecoder();
  final frames =
      List.generate(encoder.sourceBlockCount, encoder.frameAt).reversed;
  for (final frame in frames) {
    decoder.addFrame(frame.bytes);
    decoder.addFrame(frame.bytes);
  }
  expect(decoder.isComplete, isTrue);
  expect(decoder.transactions, transactions);
  expect(decoder.transactionMaps,
      transactions.map((transaction) => transaction.toMap()).toList());
}
