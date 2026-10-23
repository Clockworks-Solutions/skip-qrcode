# SkipQRCode

A [Skip](https://skip.dev) Swift/Kotlin library that generates and scans QR codes with one SwiftUI API on iOS and Android.

- **Generate**: `QRCodeView` draws text as a QR code; `QRCode` exports it as a PNG or exposes its modules
- **Scan**: `QRScannerView` is a live camera box that reports each QR code it sees
- **Camera access**: `CameraAccess` checks, requests, and recovers camera permission

## Installation

Add SkipQRCode as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/skiptools/skip-qrcode.git", "0.0.1"..<"2.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SkipQRCode", package: "skip-qrcode")
        ]
    )
]
```

On iOS, add a camera usage description to your app's `Info.plist`. On Android, the `CAMERA` permission is merged from the package's manifest.

```xml
<key>NSCameraUsageDescription</key>
<string>The camera is used to scan QR codes.</string>
```

## Generating QR Codes

### Displaying a Code

`QRCodeView` draws text as a QR code, black on white with the standard quiet zone. It scales to fit the space it is given while staying square and sharp:

```swift
import SwiftUI
import SkipQRCode

struct ShareView: View {
    var body: some View {
        QRCodeView("https://skip.tools")
            .frame(width: 240, height: 240)
    }
}
```

Use a higher error correction level when the code may be printed small, damaged, or partly covered by a logo:

```swift
QRCodeView("https://skip.tools", correction: .high)
```

The code is always square and sharp: in a frame of any shape, it fits inside and is centered. Nothing is drawn when the text is empty or too long to encode.

### Exporting an Image

`QRCode` encodes text into a grid of modules. Use `pngData(scale:)` to save or share the code as an image:

```swift
let code = try QRCode("https://skip.tools")
if let png = code.pngData(scale: 10) {
    try png.write(to: URL.documentsDirectory.appending(path: "qrcode.png"))
}
```

`scale` is the number of pixels per module, so the image is `(code.size + 8) * scale` pixels wide. Encoding throws `QRCodeError.emptyText` or `QRCodeError.tooLong` when the text can't be encoded.

### Custom Rendering

Read the modules directly to draw the code in your own style:

```swift
let code = try QRCode("Skip")
for y in 0..<code.size {
    for x in 0..<code.size where code.isDark(x: x, y: y) {
        // draw a dot at (x, y)
    }
}
```

## Scanning QR Codes

### The Scanner

`QRScannerView` is a live camera preview that reports each QR code as it comes into view. A code that stays in view is reported once.

It is as flexible as any SwiftUI view, from a small box to the whole screen:

```swift
// A small square box
QRScannerView { code in scannedCode = code }
    .frame(width: 160, height: 160)
    .clipShape(RoundedRectangle(cornerRadius: 16))

// A full-width banner
QRScannerView { code in scannedCode = code }
    .frame(height: 320)

// The whole screen: no frame needed
QRScannerView { code in scannedCode = code }
    .ignoresSafeArea()
```

Without a frame it covers the screen: it takes all the space it is offered, and the screen's size along an axis left open, such as a `ScrollView`'s or `List`'s height. The camera image fills the view and is cropped to its shape, and only codes visible inside the view are reported.

`QRScannerView` only scans: show it when `CameraAccess.status` is `.authorized`.

### Camera Access

`CameraAccess` tells you whether the app can scan, asks the user while the system still can, and opens Settings when only the user can turn access back on:

```swift
struct ScanScreen: View {
    @State var status = CameraAccess.status
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        Group {
            switch status {
            case .authorized:
                QRScannerView { code in print(code) }
            case .notDetermined:
                Button("Allow Camera") { Task { status = await CameraAccess.request() } }
            case .denied:
                Button("Open Settings") { Task { await CameraAccess.openSettings() } }
            case .restricted, .unsupported:
                Text("Scanning isn't available on this device")
            }
        }
        .task { status = await CameraAccess.request() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { status = CameraAccess.status } // back from Settings
        }
    }
}
```

| Status | Meaning | Next step |
|---|---|---|
| `.authorized` | Access granted and the device can scan | Show `QRScannerView` |
| `.notDetermined` | The system can still ask | `CameraAccess.request()` |
| `.denied` | The user turned access off | `CameraAccess.openSettings()` |
| `.restricted` | Blocked by device policy, such as parental controls | Explain; the user can't change it |
| `.unsupported` | No usable camera, or the iOS Simulator | Hide scanning |

On Android, a first denial still lets the app ask once more, so `status` stays `.notDetermined` until the user denies again.

## API Reference

### `QRCodeView`

```swift
public struct QRCodeView: View {
    public init(_ text: String, correction: QRCorrection = .medium)
}
```

### `QRCode`

```swift
public struct QRCode {
    public let size: Int
    public init(_ text: String, correction: QRCorrection = .medium) throws
    public func isDark(x: Int, y: Int) -> Bool
    public func pngData(scale: Int = 10) -> Data?
}
```

- `size`: Modules on each side, excluding the quiet zone (21 to 177)
- `init`: Throws `QRCodeError.emptyText` or `QRCodeError.tooLong` when the text can't be encoded
- `isDark(x:y:)`: Whether a module is dark; modules outside the grid are light
- `pngData(scale:)`: PNG image, black on white with a 4-module quiet zone

### `QRCorrection`

How much of the code can be damaged and still be read: `.low` (7%), `.medium` (15%), `.quartile` (25%) or `.high` (30%).

### `QRScannerView`

```swift
public struct QRScannerView: View {
    public init(onScan: @escaping (String) -> Void)
}
```

- `onScan`: Called on the main thread with each QR code's text as it comes into view

### `CameraAccess`

Main-actor camera permission checks for `QRScannerView`.

```swift
public struct CameraAccess {
    public static var status: CameraStatus { get }
    public static func request() async -> CameraStatus
    public static func openSettings() async -> Bool
}
```

- `status`: The current status, without asking the user
- `request()`: Asks the user only while the status is `.notDetermined`, then returns the new status
- `openSettings()`: Opens the app's page in Settings (iOS) or App info (Android)

### `CameraStatus`

`.authorized`, `.notDetermined`, `.denied`, `.restricted` or `.unsupported`. See [Camera Access](#camera-access).

## Architecture

SkipQRCode is a transpiled Skip package with bridging, so it works in both Skip Lite and Skip Fuse apps.

| | iOS | Android |
|---|---|---|
| Generation | Core Image `CIQRCodeGenerator` → SwiftUI `Image` | [ZXing](https://github.com/zxing/zxing) → `Bitmap` → Compose `Image` |
| Scanning | VisionKit `DataScannerViewController` | CameraX preview + ML Kit barcode scanning (`QRScanner.kt`) |
| Camera access | `AVCaptureDevice` authorization status | Runtime `CAMERA` permission |

## Requirements

- **iOS**: 17.0 or later; scanning needs a device with a camera, not the Simulator
- **Android**: the minimum Android version supported by Skip
- **Skip**: 1.6.27 or later

## Building and Testing

Install Skip using [Homebrew](https://brew.sh):

```bash
brew install skiptools/skip/skip
```

Run the tests on macOS and, transpiled, on Robolectric:

```bash
swift test
```

## Troubleshooting

**The scanner stays black**
- Check that `CameraAccess.status` is `.authorized` before showing `QRScannerView`
- On iOS, check that `NSCameraUsageDescription` is in your `Info.plist`
- On Android, check Logcat for errors tagged `QRScanner`

**Codes aren't detected**
- `QRScannerView` reads QR codes only, not other barcode types
- Only codes fully inside the view are reported; in a small box, move the code into the frame
- Make sure the code is well lit

## License

This software is licensed under the
[Mozilla Public License 2.0](https://www.mozilla.org/MPL/).
