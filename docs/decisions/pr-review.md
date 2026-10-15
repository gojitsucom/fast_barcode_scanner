# PR Review Decisions

Technical decisions made during code review, captured as reusable principles.

Each entry answers: **"Why do we do it this way?"**

---

### 2026-10-15 PR #21

**Category**: architecture
**Context**: `fast_barcode_scanner/ios/Classes/Camera.swift` — iOS capture session lifecycle (start, stop, reconfigure, recovery after interruptions).

**Q: Why does all AVCaptureSession state go through `sessionQueue`?**

**A:** `startRunning` and `stopRunning` block, so they run on the serial `sessionQueue`. Configuring the session from another thread can land between `beginConfiguration` and `commitConfiguration` while a start is running, which throws `NSGenericException`. Flags such as `shouldBeRunning` that decide whether to restart the session are read on that queue, so they are written there too. Anything that can throw (format lookup, creating the device input) runs before `beginConfiguration`, so a failure never commits a session with its inputs removed.

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
