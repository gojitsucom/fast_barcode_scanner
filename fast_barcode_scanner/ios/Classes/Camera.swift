import AVFoundation
import UIKit

/// Error codes forwarded to Dart for session lifecycle failures.
/// Must stay in sync with `ScannerErrorCodes` in
/// fast_barcode_scanner_platform_interface.
enum SessionErrorCode {
    static let interrupted = "SESSION_INTERRUPTED"
    static let interruptionEnded = "SESSION_INTERRUPTION_ENDED"
    static let startFailed = "SESSION_START_FAILED"
}

class Camera: NSObject {

    // MARK: Session Management

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "fast_barcode_scanner.session.serial")
    private var deviceInput: AVCaptureDeviceInput!
    private var captureDevice: AVCaptureDevice { deviceInput.device }
    private var scanner: BarcodeScanner

    private(set) var configuration: ScannerConfiguration
    private(set) var previewConfiguration: PreviewConfiguration!
    private var torchState = false

    /// Whether `start()` has been requested without a matching `stop()`.
    /// Used to decide if the session should be revived after interruptions
    /// and foreground transitions. Only accessed on `sessionQueue`.
    private var shouldBeRunning = false

    /// Reports session lifecycle failures (see `SessionErrorCode`) so the
    /// Dart side can show a recoverable error instead of a black preview.
    var onSessionError: ((_ code: String, _ message: String, _ details: String?) -> Void)?

    init(configuration: ScannerConfiguration, scanner: BarcodeScanner) throws {
        self.scanner = scanner
        self.configuration = configuration
        super.init()

        var authorizationGranted = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                authorizationGranted = granted
                self.sessionQueue.resume()
            }
        default:
            authorizationGranted = false
        }

        try sessionQueue.sync {
            if authorizationGranted {
                try self.applyConfiguration(configuration)
                self.addObservers()
            } else {
                throw ScannerError.unauthorized
            }
        }
    }

    deinit {
        removeObservers()
    }

    /// Session changes must be serialized with startRunning/stopRunning on
    /// `sessionQueue`; calling startRunning between begin/commitConfiguration
    /// throws an NSGenericException.
    func configureSession(configuration: ScannerConfiguration) throws {
        try sessionQueue.sync {
            try applyConfiguration(configuration)
        }
    }

    private func applyConfiguration(_ configuration: ScannerConfiguration) throws {
        let requestedDevice: AVCaptureDevice?
        let requestedPosition = configuration.cameraPosition

        // Grab the requested camera device, otherwise toggle the position and try again.
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video,
                                                position: requestedPosition) {
            requestedDevice = device
        } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: requestedPosition == .back ? .front : .back) {
            requestedDevice = device
        } else {
            // Try any available camera as fallback
            let allDevices = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                mediaType: .video,
                position: .unspecified
            ).devices
            requestedDevice = allDevices.first
        }

        guard let device = requestedDevice else {
            throw ScannerError.noInputDeviceForConfig(configuration)
        }

        // Everything that can throw runs before the session is touched, so a
        // failure leaves the current input in place instead of committing an
        // input-less session.
        guard let optimalFormat = device.formats.first(where: {
            let dimensions = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            let mediaSubType = CMFormatDescriptionGetMediaSubType($0.formatDescription).toString()

            return $0.videoSupportedFrameRateRanges.first!.maxFrameRate >= configuration.framerate.doubleValue
                && dimensions.height >= configuration.resolution.height
                && dimensions.width >= configuration.resolution.width
                && mediaSubType == "420f" // maybe 420v is also ok? Who knows...
        }) else {
            throw ScannerError.cameraNotSuitable
        }

        let deviceInput = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.inputs.forEach(session.removeInput)

        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
            self.deviceInput = deviceInput
        } else {
            throw ScannerError.configurationError("Could not add video device input to session")
        }

        // Attach scanner to the session
        self.scanner.session = session
        self.scanner.symbologies = configuration.codes
        self.scanner.onDetection = { [unowned self] in
            switch configuration.detectionMode {
            case .pauseDetection:
                self.scanner.stop()
            case .pauseVideo:
                self.stop()
            case .continuous: break
            }
        }

        do {
            try captureDevice.lockForConfiguration()
            captureDevice.activeFormat = optimalFormat
            captureDevice.activeVideoMaxFrameDuration =
                optimalFormat.videoSupportedFrameRateRanges.first!.minFrameDuration
            captureDevice.unlockForConfiguration()
        } catch {
            throw ScannerError.configurationError(error.localizedDescription)
        }

        let previewSize = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)

        self.configuration = configuration

        self.previewConfiguration = PreviewConfiguration(
            textureId: Int64(0),
            targetRotation: Int64(0),
            height: Int64(previewSize.height),
            width: Int64(previewSize.width),
            analysisWidth: Int64(previewSize.width),
            analysisHeight: Int64(previewSize.height)
        )
    }

    func start() throws {
        scanner.start()
        sessionQueue.async {
            self.shouldBeRunning = true
            self.session.startRunning()
            if !self.session.isRunning {
                self.onSessionError?(
                    SessionErrorCode.startFailed,
                    "The capture session did not start running",
                    nil
                )
            }
        }

        if torchState {
            try toggleTorch()
        }
    }

    func stop() {
        torchState = captureDevice.isTorchActive
        sessionQueue.async {
            self.shouldBeRunning = false
            self.session.stopRunning()
        }
    }

    @discardableResult
    func toggleTorch() throws -> Bool {
        guard captureDevice.isTorchAvailable else { return false }

        try captureDevice.lockForConfiguration()
        captureDevice.torchMode = captureDevice.isTorchActive ? .off : .on
        captureDevice.unlockForConfiguration()

        return captureDevice.torchMode == .on
    }

    func startDetector() {
        scanner.start()
    }

    func stopDetector() {
        scanner.stop()
    }

    // MARK: KVO and Notifications
    func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: .AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: AVError handling

    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }

        guard error.code == .mediaServicesWereReset else { return }

        sessionQueue.async {
            guard self.shouldBeRunning else { return }

            self.session.startRunning()
            if !self.session.isRunning {
                self.onSessionError?(
                    SessionErrorCode.startFailed,
                    "The capture session did not recover from a runtime error",
                    error.localizedDescription
                )
            }
        }
    }

    // MARK: Interruption handling

    @objc
    func sessionWasInterrupted(notification: NSNotification) {
        var reasonDescription: String?
        if let userInfo = notification.userInfo,
           let reasonValue = userInfo[AVCaptureSessionInterruptionReasonKey] as? Int,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue) {
            reasonDescription = String(describing: reason)
        }

        onSessionError?(
            SessionErrorCode.interrupted,
            "The camera session was interrupted",
            reasonDescription
        )
    }

    @objc
    func sessionInterruptionEnded(notification: NSNotification) {
        // AVFoundation resumes the session automatically after most
        // interruptions, but not all — verify and revive if needed.
        reviveSessionIfNeeded(context: "after an interruption")
    }

    @objc
    func appWillEnterForeground(notification: NSNotification) {
        reviveSessionIfNeeded(context: "after returning to the foreground")
    }

    private func reviveSessionIfNeeded(context: String) {
        sessionQueue.async {
            guard self.shouldBeRunning else { return }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            if self.session.isRunning && !self.session.isInterrupted {
                self.onSessionError?(
                    SessionErrorCode.interruptionEnded,
                    "The camera session resumed",
                    nil
                )
            } else if !self.session.isRunning {
                self.onSessionError?(
                    SessionErrorCode.startFailed,
                    "The capture session did not resume \(context)",
                    nil
                )
            }
        }
    }
}
