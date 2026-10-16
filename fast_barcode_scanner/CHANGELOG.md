## 3.2.1
- `CameraController.clearCachedImage()` no longer disposes the camera. It only clears the cached images. Previously it also called the platform `dispose()`, which stopped whichever camera was open at the time while the Dart state still reported it initialized, leaving a frozen preview. Callers that relied on it to shut the camera down must call `dispose()` instead.

## 3.2.0
- iOS: fix the `NSGenericException` crash "startRunning may not be called between calls to beginConfiguration and commitConfiguration". `changeConfiguration` now runs on the serial session queue so it cannot overlap a session start, and the configuration is always committed, even when adding the camera input fails.

## 3.1.0
- iOS: detect and recover from capture session interruptions instead of showing a silent black preview. The camera now observes `AVCaptureSessionWasInterrupted`/`InterruptionEnded`, verifies that `startRunning` actually took effect, revives the session on foreground, and reports failures to Dart as `ScannerEvent.error` (rendered via `BarcodeCamera.onError`), clearing the error automatically when the session resumes.
- iOS: run session start/stop on the serial session queue instead of the global concurrent queue.
- iOS: re-initializing while a camera instance already exists now ensures its session is running instead of silently returning a stopped session's configuration.

## 3.0.2
## 3.0.1
- Fix camera preview ios

## 3.0.0
- Migrate to Pigeon for platform communication

## 2.6.1
- Use `context` directly from `pluginBinding` instead of `camera`'s context in `clearCachedImage`

## 2.6.0
- Update MLKit Barcode Scanning version for Android

## 2.5.0
- Remove clearImageCache() from `CameraController`'s dispose method.

## 2.4.6
- Add android namespace

## 2.4.4
## 2.4.3
## 2.4.2

- Return when camera is already initialized and during `stop()`

## 2.3.1

- move clear cache before disposing of controller

## 2.3.0
## 2.2.2

- Add 2 methods `retrieveCachedImage` and `clearCachedImage` which allow retrieving the cached image with the scanned code.

## 2.1.0
- Add flutter exception handling, safe set state for barcode camera

## 2.0.0-dev.10
- Update nexus to gojitsu

## 2.0.0-dev.9
- fix android build

## 2.0.0-dev.8
- Fix iOS freezing issue

## 2.0.0-dev.7
- Fix error handling for iOS Vision scanner

## 2.0.0-dev.2

- Analyze still images from binary or native image pickers on iOS and Android
- Added options to customize the QR scanner: sensingColor, backgroundColor, cutOutShape, cutOutBorderColor
- Added first tests
- Even more refactoring
- Simplified Readme

## 2.0.0-dev.1

- Added ability to change the scanner configuration while running
- Restructured and simplified native code on iOS and Android
- Fully implemented error handling
- UPC-A is now correctly reported on iOS (EAN-13 with a leading 0 is regarded as UPC-A).
- Massively improved sample app with controls over all features.
- Updated CameraX and ML Kit to the newest versions

## 1.1.4

- Fixes `pauseDetector` on iOS
- Fixes no error reported when permissions are denied on Android
- Updates CameraX (compileSdk is now 31)

## 1.1.3

- Remove references to FlutterActivity (required by local_auth package)

## 1.1.2

- Fixed a bug where the app would crash when denying permissions on iOS.
- Smaller code cleanups
- Updated CameraX and ML Kit to latest versions.

## 1.1.1

- Camera position now taken into account on Android.
- Fix DetectionMode.pauseDetection on Android.
- Updated CameraX to v1.1.0-alpha05

## 1.1.0

- Relaxed kotlin version to 1.3.50
- Updated MLKit version (16.1.2)
- The camera state now contains the torch state (on/off)
- Fixed toggling the torch in the example project

## 1.0.2

- Even more documentation.

## 1.0.1

- Updated documentation.

## 1.0.0

- Initial pre-release.
