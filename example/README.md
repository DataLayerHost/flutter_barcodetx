# BarcodeTX scanner example

This example uses `mobile_scanner` only as a camera adapter. The byte list in `Barcode.rawDecodedBytes` is passed directly to `BarcodeTxDecoder.addFrame`; the BarcodeTX package itself has no scanner dependency.

```sh
cd example
flutter pub get
flutter run
```

Add the camera permission required by `mobile_scanner` to the generated Android/iOS host before running on a device. The example intentionally does not fall back to `rawValue`, because a UTF-8 string cannot losslessly represent an arbitrary binary BarcodeTX frame.
