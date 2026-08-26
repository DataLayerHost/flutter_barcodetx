# BarcodeTX Protocol v1

All integers are unsigned and big-endian. Offsets are zero-based. Text is strict ASCII. Decoders must reject reserved values, trailing batch bytes, inconsistent metadata, arithmetic overflow, and lengths exceeding local limits before allocation.

## Canonical transaction batch

| Offset | Size | Field | Value |
| ---: | ---: | --- | --- |
| 0 | 4 | magic | `42 54 58 42` (`BTXB`) |
| 4 | 1 | version | `01` |
| 5 | 2 | transaction count | 1–256 by default |
| 7 | variable | transaction entries | In original input order |

Each entry is contiguous:

| Relative offset | Size | Field |
| ---: | ---: | --- |
| 0 | 1 | `TYPE_LENGTH` |
| 1 | `TYPE_LENGTH` | uppercase ASCII type |
| `1 + TYPE_LENGTH` | 4 | raw transaction byte length |
| `5 + TYPE_LENGTH` | declared length | opaque signed transaction bytes |

The type grammar is `[A-Z0-9][A-Z0-9._+-]*`. Default limits are 32 type bytes, 512 KiB per transaction, 256 transactions, and 1 MiB for the complete canonical batch. Zero-length transactions are invalid. Public hex is decoded pairwise to these raw bytes.

## Protected fountain payload and transfer ID

Let `B` be the complete canonical batch bytes and `H = SHA-256(B)` (32 bytes). The fountain payload is:

```text
P = B || H
```

The transfer ID is `H[0:6]`, exposed as 12 uppercase hexadecimal characters. Six truncated digest bytes provide grouping and accidental-collision avoidance only, not authentication. On completion a decoder must verify both `SHA-256(B) == H` and `H[0:6] == frame transfer ID` before deserializing.

## Source blocks

`P` is divided in order into `K = ceil(length(P) / S)` blocks of exactly `S` bytes. `S` is the frame's block-size field. Only the final block is right-padded with zero bytes. `K` must equal the frame source-count field. After reconstruction, padding is removed using the declared protected-payload length.

## Deterministic fountain symbols

Every symbol has a 32-bit `SYMBOL_ID` and is the bitwise XOR of selected source blocks:

- If `SYMBOL_ID < K`, select only block `SYMBOL_ID` (systematic degree 1).
- Otherwise seed a 32-bit state with `(SYMBOL_ID * 0x9E3779B1) mod 2^32`, then for transfer-ID byte `t[i]`, in order, set `state = state XOR (t[i] << (8 * (i mod 4)))`.
- `next()` applies unsigned 32-bit xorshift32: `state ^= state << 13; state ^= state >>> 17; state ^= state << 5`, truncating to 32 bits after each left shift and returning the 32-bit state.
- Let `Dmax = min(K, 8)`. For `K == 1`, degree is 1. Otherwise degree is `2 + (next() mod (Dmax - 1))`, producing 2 through `Dmax`.
- Repeatedly select `next() mod K` into a set until the set contains `degree` distinct indices. XOR those source blocks. Sorting the selected indices is recommended for deterministic implementations but does not change XOR output.

The decoder independently derives the selection and rejects a mismatched transmitted degree. It collects binary linear equations and uses Gaussian elimination over GF(2). It completes only at rank `K`; duplicate symbol IDs are ignored. This is a systematic LT-style fountain/rateless erasure code. It does not promise a fixed overhead: senders continue producing symbols until the receiver reports completion.

## Binary QR frame

The total frame size is `27 + S` bytes.

| Offset | Size | Field | v1 value / meaning |
| ---: | ---: | --- | --- |
| 0 | 2 | magic | `42 58` (`BX`) |
| 2 | 1 | frame version | `01` |
| 3 | 1 | flags | `00`; all bits reserved |
| 4 | 6 | transfer ID | raw `H[0:6]` |
| 10 | 4 | protected-payload length | `length(P)` |
| 14 | 2 | source block size `S` | raw symbol data length |
| 16 | 2 | source block count `K` | exactly `ceil(length(P)/S)` |
| 18 | 4 | symbol ID | deterministic fountain sequence number |
| 22 | 1 | degree | 1–8 and equal to derived degree |
| 23 | `S` | fountain symbol | XOR result |
| `23 + S` | 4 | frame CRC-32 | CRC of every preceding frame byte |

CRC-32 is the IEEE reflected polynomial `0xEDB88320`, initial state `0xFFFFFFFF`, bytewise input, final XOR `0xFFFFFFFF`. It detects corrupted symbol/metadata bytes before solving; it is not cryptographic authentication.

The default `S` is 773 because the default maximum frame is 800 bytes. The configured maximum frame must be at least 28 bytes and no larger than the QR version-40 byte-mode capacity at the selected error correction: L 2953, M 2331, Q 1663, or H 1273 bytes. Applications should prefer the conservative default.

## Decoder behavior

1. Check maximum input size, minimum size, magic, version, flags, and CRC.
2. Validate protected length, block size, source count, degree, and exact frame length without allocation from unchecked fields.
3. The first valid frame selects its transfer ID and fixed fountain metadata.
4. Ignore different-transfer frames. Reject same-transfer frames with inconsistent metadata.
5. Deduplicate IDs, derive their coefficients, and insert equations in arbitrary arrival order.
6. At full rank reconstruct `P`, remove only declared right padding, verify SHA-256 and transfer ID, then strictly deserialize `B`.

Default receipt is capped at 8,192 distinct symbol IDs. Applications may lower limits. A decoder instance handles one transfer; create a new instance to scan another.

## Layer separation

QR visual Reed-Solomon repairs module-level scan errors. Fountain coding repairs missing complete frames. CRC-32 rejects malformed individual binary envelopes. SHA-256 verifies reconstructed payload integrity. The 48-bit ID separates simultaneous sessions. None authenticates the sender.
