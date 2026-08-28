# Security

## Scope

BarcodeTX transports caller-supplied, already-signed transaction bytes. It never handles private keys, signs or broadcasts transactions, interprets chain formats, validates consensus, or establishes that a transaction is safe. Applications must show and independently validate the destination, amount, network, fees, and other relevant details before broadcast.

## Trust model

Scanned frames are untrusted. Version 1 provides accidental-corruption detection, erasure recovery, full-payload integrity, and transfer grouping. SHA-256 here is unkeyed: an attacker able to replace the complete stream can create another internally valid stream. The six-byte transfer ID is not an authenticator and has 48-bit collision resistance at most.

For authenticity, bind the transaction to an authenticated workflow outside BarcodeTX—for example, compare details on a trusted signing device or carry a signature from an independently trusted identity.

## Defensive defaults

- maximum QR payload: 800 bytes
- maximum canonical batch: 1 MiB
- maximum transaction: 512 KiB
- maximum transactions: 256
- blockchain code: exactly 3 uppercase ASCII letters
- optional network ID: unsigned 32-bit integer
- maximum accepted distinct symbols: 8,192
- exact length/count consistency and no trailing batch bytes
- CRC-32 before fountain insertion
- SHA-256 and transfer-ID verification before returning data

Applications processing smaller transactions should lower these limits. Do not raise them from values supplied by a QR frame.

## Reporting vulnerabilities

Please report security issues privately through GitHub's security advisory interface for `DataLayerHost/flutter_barcodetx`. Never include private keys, seed phrases, or production signed transactions in a report; use synthetic test vectors.
