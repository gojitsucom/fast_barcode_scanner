# PR Review Decisions

Technical decisions made during code review, captured as reusable principles.

Each entry answers: **"Why do we do it this way?"**

---

### 2026-10-15 PR #21

**Category**: architecture
**Context**: `fast_barcode_scanner/ios/Classes/Camera.swift` — iOS capture session lifecycle (start, stop, reconfigure, recovery after interruptions).

**Q: Why does all AVCaptureSession state go through `sessionQueue`?**

**A:** `startRunning` and `stopRunning` block, so they run on the serial `sessionQueue`. Configuring the session from another thread can land between `beginConfiguration` and `commitConfiguration` while a start is running, which throws `NSGenericException`. State that decides how to restart the session, such as `shouldBeRunning` and the saved torch state, is read on that queue, so it is written there too. The torch is set after `startRunning` succeeds, because it does not stay on for a session that is not running. Anything that can throw (format lookup, creating the device input, `lockForConfiguration`) runs before `beginConfiguration`, so a failure leaves the current input and configuration in place. The device stays locked until after `commitConfiguration`. The one check that can only run after the old input is removed, `canAddInput`, restores the previous inputs before throwing.

**Example:**
```swift
// Before: main thread, races startRunning on sessionQueue
try camera.configureSession(configuration: config)

// After
func configureSession(configuration: ScannerConfiguration) throws {
    try sessionQueue.sync { try applyConfiguration(configuration) }
}
```

*Reviewer: @gemini-code-assist*

---

### 2026-10-16 PR #21

**Category**: error-handling
**Context**: `fast_barcode_scanner/lib/src/camera_controller.dart` and `fast_barcode_scanner/ios/Classes/Camera.swift` — mapping native session lifecycle signals onto `ScannerEvent`.

**Q: Why are session interruptions not reported as scanner errors?**

**A:** Interruptions (backgrounding, phone calls, Siri, Split View, another app using the camera) end on their own. Mapping them to `ScannerEvent.error` makes `BarcodeCamera` replace the preview with `onError` during normal use, which in the driver app is a full error screen with a Go back button. Only a start or revive that actually fails is an error, plus one exception: an interruption still active 3 seconds later while the app is in the foreground (for example, another app holding the camera in Split View) is reported as a start failure, because otherwise the preview stays frozen with no error. The background reason is excluded, since the foreground revive covers it. The native side skips start-failure reports while the session is interrupted, and sends `SESSION_INTERRUPTION_ENDED` only to clear a failure it reported itself, either when a later start succeeds or when the session resumes, so a foreground transition does not hide unrelated errors.

**Example:**
```dart
// Before
case ScannerErrorCodes.sessionInterrupted:
case ScannerErrorCodes.sessionStartFailed:
  events.value = ScannerEvent.error;

// After
case ScannerErrorCodes.sessionStartFailed:
  events.value = ScannerEvent.error;
```

*Reviewer: @nogicoder*

---
