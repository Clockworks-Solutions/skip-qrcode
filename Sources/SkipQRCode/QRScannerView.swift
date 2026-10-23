// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import SwiftUI
#if os(iOS)
import VisionKit
#endif

/// Live camera preview that reports each QR code as it comes into view.
///
/// The preview fills the space it is given, so size and shape it like any view, for example with
/// `frame` and `clipShape`. Without a frame it covers the screen, even inside a scroll view.
/// It only scans: show it when `CameraAccess.status` is `.authorized`.
/// Scanning uses VisionKit on iOS, and CameraX with ML Kit on Android.
public struct QRScannerView: View {
    let onScan: (String) -> Void

    public init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
    }

    #if SKIP
    public var body: some View {
        ComposeView { context in
            ComposeContainer(modifier: context.modifier, fillWidth: true, fillHeight: true) { modifier in
                QRScanner(modifier: modifier, onScan: onScan)
            }
        }
    }
    #elseif os(iOS)
    public var body: some View {
        DataScanner(onScan: onScan)
    }
    #else
    public var body: some View {
        Color.black
    }
    #endif
}

#if os(iOS)
/// VisionKit scanner reporting each QR code once as it comes into view.
struct DataScanner: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        // No guidance overlay, whose hints don't fit small boxes; highlights still mark each code
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    /// Takes the offered size, and the screen's along any axis left open, such as a scroll view's.
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController scanner: DataScannerViewController, context: Context) -> CGSize? {
        let scene = scanner.view.window?.windowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        let screen = scene?.screen.bounds.size ?? .zero
        return CGSize(width: proposal.width ?? screen.width, height: proposal.height ?? screen.height)
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for case .barcode(let barcode) in addedItems {
                if let value = barcode.payloadStringValue {
                    onScan(value)
                }
            }
        }
    }
}
#endif
#endif
