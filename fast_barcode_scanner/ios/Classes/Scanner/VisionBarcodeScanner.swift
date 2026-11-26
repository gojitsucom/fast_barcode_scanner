import Flutter
import AVFoundation
import Vision

@available(iOS 11.0, *)
typealias VisionBarcodeCornerPointConverter = (VNBarcodeObservation) -> [[Int]]?

@available(iOS 11.0, *)
class VisionBarcodeScanner: NSObject, BarcodeScanner, AVCaptureVideoDataOutputSampleBufferDelegate {
    typealias ErrorHandler = (FlutterError?) -> Void

    typealias Barcode = VNBarcodeObservation

    var resultHandler: ResultHandler
    var errorHandler: ErrorHandler
    var cornerPointConverter: VisionBarcodeCornerPointConverter
    var confidence: Double
    var onDetection: (() -> Void)?
    var capturedImage: UIImage?
    var onCacheImage: ((String, UIImage) -> Void)
    private let cachesLegacyImage: Bool
    private let frameRing: FrameRing<CGImage>?
    private let ciContext = CIContext()

    /// The frame Vision is reading right now. `perform` calls the completion handler before it
    /// returns, so the handler keeps the pixels of the buffer its codes came from.
    private var detectingFrame: (image: CIImage, ringGeneration: Int64)?

    private static let maxFrameLongEdge: CGFloat = 1280

    private let output = AVCaptureVideoDataOutput()
    private let outputQueue = DispatchQueue(label: "fast_barcode_scanner.data.serial", qos: .userInitiated,
            attributes: [], autoreleaseFrequency: .workItem)
    private lazy var visionBarcodesRequests: [VNDetectBarcodesRequest]! = {
        let request = VNDetectBarcodesRequest(completionHandler: handleVisionRequestUpdate)
        if #available(iOS 15, *) {
            request.revision = VNDetectBarcodesRequestRevision2
        }
        return [request]
    }()

    private let visionSequenceHandler = VNSequenceRequestHandler()

    private var _session: AVCaptureSession?
    private var _symbologies = [String]()

    var symbologies: [String] {
        get {
            _symbologies
        }
        set {
            _symbologies = newValue

            // Convert string types to BarcodeType enums, then to VNBarcodeSymbology
            let barcodeTypes = newValue.compactMap { BarcodeType.fromString($0) }
            visionBarcodesRequests.first!.symbologies = barcodeTypes.compactMap({ vnBarcodeSymbols[$0] })

            // UPC-A is reported as EAN-13
            if newValue.contains("upcA") && !visionBarcodesRequests.first!.symbologies.contains(.EAN13) {
                visionBarcodesRequests.first!.symbologies.append(.EAN13)
            }

            // Report to the user if any types are not supported
            if visionBarcodesRequests.first!.symbologies.count != newValue.count {
                let unsupportedTypes = newValue.filter { typeString in
                    guard let barcodeType = BarcodeType.fromString(typeString) else { return true }
                    return vnBarcodeSymbols[barcodeType] == nil
                }
                print("WARNING: Unsupported barcode types selected: \(unsupportedTypes)")
            }
        }
    }

    var session: AVCaptureSession? {
        get {
            _session
        }
        set {
            _session = newValue
            if let session = newValue, session.canAddOutput(output), !session.outputs.contains(output) {
                session.addOutput(output)
            }
        }
    }

    init(cornerPointConverter: @escaping VisionBarcodeCornerPointConverter, confidence: Double, onCacheImage: ((String, UIImage) -> Void)?, frameRing: FrameRing<CGImage>? = nil, resultHandler: @escaping ResultHandler, errorHandler: @escaping ErrorHandler) {
        self.resultHandler = resultHandler
        self.errorHandler = errorHandler
        self.cornerPointConverter = cornerPointConverter
        self.confidence = confidence
        // Nil turns the legacy per-code image cache off, which also skips its full-size copy per frame.
        self.onCacheImage = onCacheImage ?? { _, _ in }
        self.cachesLegacyImage = onCacheImage != nil
        self.frameRing = frameRing
        super.init()

        output.alwaysDiscardsLateVideoFrames = true
    }

    func start() {
        output.setSampleBufferDelegate(self, queue: outputQueue)
    }

    func stop() {
        output.setSampleBufferDelegate(nil, queue: nil)
    }

    // MARK: Vision capture output

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            if cachesLegacyImage, let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                capturedImage = UIImage(cgImage: cgImage, scale: 1, orientation: .right)
            }
            if let frameRing = frameRing {
                detectingFrame = (ciImage, frameRing.generation)
            }
            defer { detectingFrame = nil }

            do {
                try visionSequenceHandler.perform(visionBarcodesRequests, on: pixelBuffer)
            } catch {
                handleVisionRequestUpdate(request: nil, error: error)
            }
        }
    }

    // MARK: Still image processing

    func process(_ cgImage: CGImage) {
        do {
            try visionSequenceHandler.perform(visionBarcodesRequests, on: cgImage)
        } catch {
            handleVisionRequestUpdate(request: nil, error: error)
        }
    }

    // MARK: Callback

    private func handleVisionRequestUpdate(request: VNRequest?, error: Error?) {
        guard let results = request?.results as? [VNBarcodeObservation] else {
            let message = error != nil ? "\(error!)" : "unknownError"
            print("Error scanning image: \(message)")
            let flutterError = FlutterError(code: "UNEXPECTED_SCAN_ERROR", message: message, details: error?._code)
            DispatchQueue.main.async {
                self.errorHandler(flutterError)
            }
            return
        }

        let barcodes: [[Any?]] = results.filter { $0.confidence > Float(confidence) }.map {
                    let pointList = cornerPointConverter($0)
                    return [flutterVNSymbols[$0.symbology]!, $0.payloadStringValue ?? "", nil, pointList]
                }

        // consolidate any duplicate scans. Code128 has been observed to produce multiple scans
        var barcodeDict = [String: [Any?]]()
        for barcode: [Any?] in barcodes {
            let barcodeType = barcode[0] as! BarcodeType
            let barcodeValue = barcode[1] as! String
            let key = "\(barcodeType.toInternalBarcodeType())|\(barcodeValue)"
            let existingBarcodes = barcodeDict[key]
            if existingBarcodes == nil {
                barcodeDict[key] = barcode
            }
        }
        var uniqueCodes = Array(barcodeDict.values)

        if !uniqueCodes.isEmpty, let frameId = keepDetectingFrame(codeValues: Set(uniqueCodes.map { $0[1] as! String })) {
            uniqueCodes = uniqueCodes.map { $0 + [frameId] }
        }

        if !uniqueCodes.isEmpty && capturedImage != nil {
            onCacheImage((uniqueCodes.first!)[1] as! String, capturedImage!)
            capturedImage = nil
        }

        onDetection?()
        DispatchQueue.main.async {
            self.resultHandler(uniqueCodes)
        }
    }

    private func keepDetectingFrame(codeValues: Set<String>) -> Int64? {
        guard let frameRing = frameRing, let frame = detectingFrame,
              let cgImage = downscaledCGImage(frame.image) else {
            return nil
        }
        return frameRing.put(codeValues: codeValues, frame: cgImage, generation: frame.ringGeneration)
    }

    private func downscaledCGImage(_ image: CIImage) -> CGImage? {
        let longEdge = max(image.extent.width, image.extent.height)
        let scale = min(1, Self.maxFrameLongEdge / longEdge)
        let scaled = scale < 1 ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : image
        return ciContext.createCGImage(scaled, from: scaled.extent.integral)
    }
}

@available(iOS 11.0, *)
extension VNBarcodeObservation {
    var pointList: [[Int]] {
        get {
            [
                [Int(topLeft.x), Int(topLeft.y)],
                [Int(topRight.x), Int(topRight.y)],
                [Int(bottomRight.x), Int(bottomRight.y)],
                [Int(bottomLeft.x), Int(bottomLeft.y)]
            ]
        }
    }
}
