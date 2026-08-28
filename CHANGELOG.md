# Changelog

## 0.2.0

- Replace variable transaction types with fixed three-letter blockchain codes.
- Add an optional unsigned 32-bit network ID to every transaction record.
- Replace the `type` API with `blockchain` and optional `networkId` fields.
- Define a single BarcodeTx v1 layout without legacy decoding.

## 0.1.0

- Initial BarcodeTX v1 binary batch and frame protocol.
- Deterministic systematic LT-style fountain encoder with Gaussian decoder.
- Raw-byte animated QR widget and camera-independent decoder.
- SHA-256 end-to-end integrity, 48-bit transfer grouping, and frame CRC-32.
- Typed/map APIs, defensive limits, protocol documentation, scanner example, benchmark, and test suite.
