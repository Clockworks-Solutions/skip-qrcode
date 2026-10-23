// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import Foundation
#if SKIP
import SwiftUI
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
#elseif os(iOS)
import AVFoundation
import UIKit
import VisionKit
#endif

/// Whether the app can use the camera to scan, and what to do when it can't.
public enum CameraStatus: Sendable {
    /// Access is granted and the device can scan: show `QRScannerView`.
    case authorized
    /// The system can still ask the user: call `CameraAccess.request()`.
    case notDetermined
    /// The user turned access off, and only Settings can turn it back on: call `CameraAccess.openSettings()`.
    case denied
    /// Device policy, such as parental controls, blocks the camera, and the user can't change it.
    case restricted
    /// The device can't scan, for example without a camera or in the iOS Simulator.
    case unsupported
}

/// Camera permission checks for `QRScannerView`.
///
/// Check `status` before showing the scanner, `request()` access while the system can still ask,
/// and `openSettings()` once the user has turned access off. Check `status` again when the app
/// becomes active, since the user may have changed it in Settings.
@MainActor
public struct CameraAccess {
    /// Set once the user denies the Android permission, which Android can't report until it is asked.
    private static let deniedKey = "SkipQRCodeCameraDenied"

    /// The current camera status, without asking the user.
    public static var status: CameraStatus {
        #if SKIP
        let context = ProcessInfo.processInfo.androidContext
        guard context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) else { return .unsupported }
        if ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED {
            return .authorized
        }
        guard UserDefaults.standard.bool(forKey: deniedKey) else { return .notDetermined }
        // After one denial Android asks once more, and reports that with the rationale flag
        if let activity = UIApplication.shared.androidActivity, ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.CAMERA) {
            return .notDetermined
        }
        return .denied
        #elseif os(iOS)
        guard DataScannerViewController.isSupported else { return .unsupported }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        default: return .denied
        }
        #else
        return .unsupported
        #endif
    }

    /// Asks the user for camera access when the system can still ask, and returns the resulting status.
    ///
    /// Returns the current status at once, without asking, when it is anything but `notDetermined`.
    @discardableResult
    public static func request() async -> CameraStatus {
        guard status == .notDetermined else { return status }
        #if SKIP
        let isGranted = await UIApplication.shared.requestPermission(Manifest.permission.CAMERA)
        UserDefaults.standard.set(!isGranted, forKey: deniedKey)
        #elseif os(iOS)
        _ = await AVCaptureDevice.requestAccess(for: .video)
        #endif
        return status
    }

    /// Opens this app's page in Settings, where the user can turn camera access back on.
    @discardableResult
    public static func openSettings() async -> Bool {
        #if SKIP || os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return false }
        return await UIApplication.shared.open(url)
        #else
        return false
        #endif
    }
}
#endif
