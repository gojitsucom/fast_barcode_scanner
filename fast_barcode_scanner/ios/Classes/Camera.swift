import AVFoundation

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
    private var isSessionRunning = false

    init(configuration: ScannerConfiguration, scanner: BarcodeScanner) throws {
        print("📷 Camera: Starting initialization")
        self.scanner = scanner
        self.configuration = configuration
        super.init()

        print("📷 Camera: Checking camera authorization")
        var authorizationGranted = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("📷 Camera: Authorization already granted")
            break
        case .notDetermined:
            print("📷 Camera: Authorization not determined, requesting access")
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                authorizationGranted = granted
                print("📷 Camera: Authorization request result: \(granted)")
                self.sessionQueue.resume()
            }
        default:
            print("📷 Camera: Authorization denied")
            authorizationGranted = false
        }

        print("📷 Camera: Configuring session on queue")
        try sessionQueue.sync {
            if authorizationGranted {
                print("📷 Camera: Authorization granted, configuring session")
                try self.configureSession(configuration: configuration)
                print("📷 Camera: Adding observers")
                self.addObservers()
                print("📷 Camera: Initialization completed successfully")
            } else {
                print("❌ Camera: Authorization not granted, throwing unauthorized error")
                throw ScannerError.unauthorized
            }
        }
    }

    deinit {
        removeObservers()
    }

    func configureSession(configuration: ScannerConfiguration) throws {
        print("📷 configureSession: Starting session configuration")
        print("📷 configureSession: Requested position: \(configuration.position)")
        print("📷 configureSession: AVCapturePosition: \(configuration.cameraPosition)")

        // List all available devices for debugging
        let allDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .unspecified
        ).devices

        print("📷 configureSession: Available devices:")
        for device in allDevices {
            print("📷   - \(device.localizedName) at position \(device.position)")
        }

        let requestedDevice: AVCaptureDevice?
        let requestedPosition = configuration.cameraPosition

        // Grab the requested camera device, otherwise toggle the position and try again.
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video,
                                                position: requestedPosition) {
            print("📷 configureSession: Found device for requested position: \(device.localizedName)")
            requestedDevice = device
        } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: requestedPosition == .back ? .front : .back) {
            print("📷 configureSession: Found device for alternate position: \(device.localizedName)")
            requestedDevice = device
        } else {
            // Try any available camera as fallback
            if let device = allDevices.first {
                print("📷 configureSession: Using fallback device: \(device.localizedName)")
                requestedDevice = device
            } else {
                print("❌ configureSession: No camera device found at all")
                requestedDevice = nil
            }
        }

        guard let device = requestedDevice else {
            print("❌ configureSession: No input device available for configuration")
            throw ScannerError.noInputDeviceForConfig(configuration)
        }

        print("📷 configureSession: Using device: \(device.localizedName)")

        print("📷 configureSession: Beginning session configuration")
        session.beginConfiguration()

        print("📷 configureSession: Removing existing inputs")
        session.inputs.forEach(session.removeInput)

        print("📷 configureSession: Creating device input")
        let deviceInput = try AVCaptureDeviceInput(device: device)

        if session.canAddInput(deviceInput) {
            print("📷 configureSession: Adding device input to session")
            session.addInput(deviceInput)
            self.deviceInput = deviceInput
        } else {
            print("❌ configureSession: Could not add video device input to session")
            throw ScannerError.configurationError("Could not add video device input to session")
        }

        print("📷 configureSession: Attaching scanner to session")
        // Attach scanner to the session
        self.scanner.session = session

        print("📷 configureSession: Setting scanner symbologies: \(configuration.codes)")
        self.scanner.symbologies = configuration.codes

        print("📷 configureSession: Setting scanner detection callback")
        self.scanner.onDetection = { [unowned self] in
            switch configuration.detectionMode {
            case .pauseDetection:
                self.scanner.stop()
            case .pauseVideo:
                self.stop()
            case .continuous: break
            }
        }

        session.commitConfiguration()

        // Find the optimal settings for the requested resolution and frame rate.
        guard let optimalFormat = captureDevice.formats.first(where: {
            let dimensions = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            let mediaSubType = CMFormatDescriptionGetMediaSubType($0.formatDescription).toString()

            return $0.videoSupportedFrameRateRanges.first!.maxFrameRate >= configuration.framerate.doubleValue
                && dimensions.height >= configuration.resolution.height
                && dimensions.width >= configuration.resolution.width
                && mediaSubType == "420f" // maybe 420v is also ok? Who knows...
        }) else {
            throw ScannerError.cameraNotSuitable
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
            textureId: 0,
            targetRotation: 0,
            height: Int64(previewSize.height),
            width: Int64(previewSize.width),
            analysisWidth: Int64(previewSize.width),
            analysisHeight: Int64(previewSize.height)
        )
    }

    func start() throws {
        scanner.start()
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
        }

        if torchState {
            try toggleTorch()
        }
    }

    func stop() {
        torchState = captureDevice.isTorchActive
        DispatchQueue.global(qos: .background).async {
            self.session.stopRunning()
            self.isSessionRunning = self.session.isRunning
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
    }

    func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionRuntimeError, object: session)
    }

    // MARK: AVError handling

    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }

        // Try to restart, if session was running
        if error.code == .mediaServicesWereReset && isSessionRunning {
            sessionQueue.async {
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
}
