import Flutter
import AVFoundation
import UIKit
import CryptoKit
import Vision

@available(iOS 11.0, *)
public class FastBarcodeScannerPlugin: NSObject, FlutterPlugin, FastBarcodeScannerHostApi {
    let factory: PreviewViewFactory
    var camera: Camera?
    var picker: ImagePicker?
    var flutterApi: FastBarcodeScannerFlutterApi?

    init(factory: PreviewViewFactory) {
        self.factory = factory
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        print("🔧 FastBarcodeScannerPlugin: Starting registration")
        let instance = FastBarcodeScannerPlugin(factory: PreviewViewFactory())

        // Set up Pigeon APIs
        print("🔧 FastBarcodeScannerPlugin: Setting up Pigeon Host API")
        FastBarcodeScannerHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)

        print("🔧 FastBarcodeScannerPlugin: Setting up Pigeon Flutter API")
        instance.flutterApi = FastBarcodeScannerFlutterApi(binaryMessenger: registrar.messenger())

        print("🔧 FastBarcodeScannerPlugin: Registering preview factory")
        registrar.register(instance.factory, withId: "fast_barcode_scanner.preview")

        print("🔧 FastBarcodeScannerPlugin: Registration completed successfully")
    }

    // MARK: - FastBarcodeScannerHostApi Implementation

    func initialize(configuration: ScannerConfiguration, completion: @escaping (Result<PreviewConfiguration, Error>) -> Void) {
        print("🚀 FastBarcodeScannerPlugin: Initialize called")
        print("🚀 Configuration: types=\(configuration.types), mode=\(configuration.mode), resolution=\(configuration.resolution)")
        print("🚀 Configuration: framerate=\(configuration.framerate), position=\(configuration.position), apiMode=\(String(describing: configuration.apiMode))")

        do {
            print("🚀 FastBarcodeScannerPlugin: Calling initializeInternal")
            let previewConfig = try initializeInternal(configuration: configuration)
            print("🚀 FastBarcodeScannerPlugin: Initialize successful, preview config: \(previewConfig)")
            completion(.success(previewConfig))
        } catch {
            print("❌ FastBarcodeScannerPlugin: Initialize failed with error: \(error)")
            completion(.failure(error))
        }
    }

    func start(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try startInternal()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    func stop(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try stopInternal()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    func startDetector(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try startDetectorInternal()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    func stopDetector(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try stopDetectorInternal()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    func dispose(completion: @escaping (Result<Void, Error>) -> Void) {
        disposeInternal()
        completion(.success(()))
    }

    func toggleTorch(completion: @escaping (Result<Bool, Error>) -> Void) {
        do {
            let torchState = try toggleTorchInternal()
            completion(.success(torchState))
        } catch {
            completion(.failure(error))
        }
    }

    func changeConfiguration(configuration: UpdateConfiguration, completion: @escaping (Result<PreviewConfiguration, Error>) -> Void) {
        do {
            let previewConfig = try changeConfigurationInternal(configuration: configuration)
            completion(.success(previewConfig))
        } catch {
            completion(.failure(error))
        }
    }

    func scanImage(imageSource: ImageSourceData, completion: @escaping (Result<[BarcodeData?], Error>) -> Void) {
        scanImageInternal(imageSource: imageSource) { result in
            switch result {
            case .success(let barcodes):
                completion(.success(barcodes))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func retrieveCachedImage(code: String, completion: @escaping (Result<String?, Error>) -> Void) {
        do {
            let imagePath = try retrieveCachedImageInternal(code: code)
            completion(.success(imagePath))
        } catch {
            completion(.failure(error))
        }
    }

    func clearCachedImage(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try clearCachedImageInternal()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Internal Implementation Methods

    func initializeInternal(configuration: ScannerConfiguration) throws -> PreviewConfiguration {
        print("🔧 initializeInternal: Starting initialization")

        guard camera == nil else {
            print("🔧 initializeInternal: Camera already exists, returning existing config")
            return camera!.previewConfiguration.toPigeonPreviewConfiguration()
        }

        print("🔧 initializeInternal: Creating scanner with apiMode: \(String(describing: configuration.apiMode))")
        let scanner: BarcodeScanner
        if configuration.apiMode == .avFoundation {
            print("🔧 initializeInternal: Using AVFoundation scanner")
            scanner = AVFoundationBarcodeScanner(barcodeObjectLayerConverter: { barcodes in
                self.factory.preview?.videoPreviewLayer.transformedMetadataObject(for: barcodes) as? AVMetadataMachineReadableCodeObject
            }, onCacheImage: onCacheImage) { [weak self] barcodes in
                // Convert to Pigeon barcodes and send via FlutterApi
                guard let self = self, let flutterApi = self.flutterApi else { return }
                if let barcodesArray = barcodes as? [Any] {
                    var pigeonBarcodes: [BarcodeData?] = []
                    for barcode in barcodesArray {
                        pigeonBarcodes.append(convertToPigeonBarcodeData(barcode))
                    }
                    flutterApi.onBarcodesDetected(barcodes: pigeonBarcodes) { _ in }
                }
            }
        } else {
            print("🔧 initializeInternal: Using Vision scanner")
            scanner = VisionBarcodeScanner(cornerPointConverter: { observation in
                var convertedPoints: [[Int]] = []

                DispatchQueue.main.sync {
                    func convert(point: CGPoint) -> CGPoint? {
                        self.factory.preview?.videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: point)
                    }

                    guard let topLeft = convert(point: CGPoint(x: observation.topLeft.x, y: 1 - observation.topLeft.y)),
                          let topRight = convert(point: CGPoint(x: observation.topRight.x, y: 1 - observation.topRight.y)),
                          let bottomRight = convert(point: CGPoint(x: observation.bottomRight.x, y: 1 - observation.bottomRight.y)),
                          let bottomLeft = convert(point: CGPoint(x: observation.bottomLeft.x, y: 1 - observation.bottomLeft.y)) else {
                        convertedPoints = []
                        return
                    }
                    convertedPoints = [
                        [Int(topRight.x), Int(topRight.y)],
                        [Int(topLeft.x), Int(topLeft.y)],
                        [Int(bottomLeft.x), Int(bottomLeft.y)],
                        [Int(bottomRight.x), Int(bottomRight.y)]
                    ]
                }

                return convertedPoints
            }, confidence: configuration.confidence ?? 0.6, onCacheImage: onCacheImage, resultHandler: { [weak self] barcodes in
                // Convert to Pigeon barcodes and send via FlutterApi
                guard let self = self, let flutterApi = self.flutterApi else { return }
                if let barcodesArray = barcodes as? [Any] {
                    var pigeonBarcodes: [BarcodeData?] = []
                    for barcode in barcodesArray {
                        pigeonBarcodes.append(convertToPigeonBarcodeData(barcode))
                    }
                    flutterApi.onBarcodesDetected(barcodes: pigeonBarcodes) { _ in }
                }
            },
            errorHandler: { [weak self] error in
                guard let self = self, let flutterApi = self.flutterApi else { return }
                let errorMessage = error?.message ?? "Unknown scanner error"
                flutterApi.onError(
                    errorCode: "SCANNER_ERROR",
                    errorMessage: errorMessage,
                    errorDetails: nil
                ) { _ in }
            }
            )
        }

        // Convert Pigeon configuration to internal configuration
        print("🔧 initializeInternal: Converting configuration")
        let internalConfig = configuration.toInternalScannerConfiguration()

        print("🔧 initializeInternal: Creating Camera instance")
        let camera = try Camera(configuration: internalConfig, scanner: scanner)

        print("🔧 initializeInternal: Setting factory session")
        // AVCaptureVideoPreviewLayer shows the current camera's session
        factory.session = camera.session

        print("🔧 initializeInternal: Starting camera")
        try camera.start()

        print("🔧 initializeInternal: Storing camera reference")
        self.camera = camera

        print("🔧 initializeInternal: Returning preview configuration")
        return camera.previewConfiguration.toPigeonPreviewConfiguration()
    }

    func startInternal() throws {
        guard let camera = camera else {
            throw ScannerError.notInitialized
        }
        try camera.start()
    }

    func stopInternal() throws {
        guard let camera = camera else {
            return
        }
        camera.stop()
    }

    func disposeInternal() {
        camera?.stop()
        camera = nil
    }

    func startDetectorInternal() throws {
        guard let camera = camera else {
            throw ScannerError.notInitialized
        }
        camera.startDetector()
    }

    func stopDetectorInternal() throws {
        guard let camera = camera else {
            throw ScannerError.notInitialized
        }
        camera.stopDetector()
    }

    func toggleTorchInternal() throws -> Bool {
        guard let camera = camera else {
            throw ScannerError.notInitialized
        }
        return try camera.toggleTorch()
    }

    func changeConfigurationInternal(configuration: UpdateConfiguration) throws -> PreviewConfiguration {
        guard let camera = camera else {
            throw ScannerError.notInitialized
        }

        // Convert Pigeon UpdateConfiguration to internal configuration
        let config = camera.configuration.copy(with: configuration)

        try camera.configureSession(configuration: config)

        return camera.previewConfiguration.toPigeonPreviewConfiguration()
    }

    func retrieveCachedImageInternal(code: String) throws -> String? {
        if let imagePath = ImageHelper.shared.retrieveImagePath(code: code) {
            return imagePath
        }
        return nil
    }

    func clearCachedImageInternal() throws {
        ImageHelper.shared.clearCache()
    }

    func scanImageInternal(imageSource: ImageSourceData, completion: @escaping (Result<[BarcodeData?], Error>) -> Void) {
        let visionResultHandler: (Any?) -> Void = { result in
            if let barcodes = result as? [Any] {
                var pigeonBarcodes: [BarcodeData?] = []
                for barcode in barcodes {
                    pigeonBarcodes.append(convertToPigeonBarcodeData(barcode))
                }
                completion(.success(pigeonBarcodes))
            } else {
                completion(.success([]))
            }
        }

        let visionErrorHandler: (FlutterError?) -> Void = { (error: FlutterError?) in
            if let flutterError = error {
                let scannerError = ScannerError.unknown(flutterError.message ?? "Unknown error")
                completion(.failure(scannerError))
            } else {
                completion(.failure(ScannerError.unknown("Unknown error")))
            }
        }

        if let imageBytes = imageSource.imageBytes {
            guard let image = UIImage(data: imageBytes.data),
                  let cgImage = image.cgImage else {
                completion(.failure(ScannerError.loadingDataFailed))
                return
            }

            let scanner = VisionBarcodeScanner(cornerPointConverter: { (_: VNBarcodeObservation) -> [[Int]]? in return [] }, confidence: 0.6, onCacheImage: onCacheImage, resultHandler: visionResultHandler, errorHandler: visionErrorHandler)
            scanner.process(cgImage)
        } else if imageSource.useImagePicker {
            guard let root = UIApplication.shared.delegate?.window??.rootViewController else {
                completion(.success([]))
                return
            }

            let imagePickerResultHandler: ImagePicker.ResultHandler = { [weak self] image in
                guard let uiImage = image,
                      let cgImage = uiImage.cgImage else {
                    completion(.success([]))
                    return
                }

                self?.picker = nil
                let scanner = VisionBarcodeScanner(cornerPointConverter: { (_: VNBarcodeObservation) -> [[Int]]? in return [] }, confidence: 0.6, onCacheImage: self!.onCacheImage, resultHandler: visionResultHandler, errorHandler: visionErrorHandler)
                scanner.process(cgImage)
            }

            if #available(iOS 14, *) {
                picker = PHImagePicker(resultHandler: imagePickerResultHandler)
            } else {
                picker = UIImagePicker(resultHandler: imagePickerResultHandler)
            }

            picker!.show(over: root)
        } else {
            completion(.success([]))
        }
    }

    func onCacheImage(code: String, scanImage: UIImage) {
        ImageHelper.shared.storeImageToCache(image: scanImage, code: code)
    }
}

class ImageHelper {
    private var savedCodes: [String: String] = [:]

    static let shared = ImageHelper()

    private init() {}

    // Store image to the path with barcode as filename
    private func storeImage(imageBytes: Data, key: String) {

        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let barcodeDirectory = documentDirectory.appendingPathComponent("barcode_images")

                if fileManager.fileExists(atPath: barcodeDirectory.path) {
                    print("Directory does not exist: \(barcodeDirectory.path)")
                }

                try fileManager.createDirectory(at: barcodeDirectory, withIntermediateDirectories: true, attributes: nil)

                let fileName = key
                if #available(iOS 13.0, *) {
                    let fileName = stringToMD5(string: key)
                }

                let imageFile = barcodeDirectory.appendingPathComponent(fileName + ".jpeg")
                try imageBytes.write(to: imageFile)

                savedCodes[key] = imageFile.absoluteString
            } catch {
                print("Error storing image: \(error)")
            }
        }
    }

    @available(iOS 13.0, *)
    private func stringToMD5(string: String) -> String {
      guard let data = string.data(using: .utf8) else {
        fatalError("Failed to convert string to data")
      }

      let digest = Insecure.MD5.hash(data: data)

      return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    private func isImageSaved(code: String) -> Bool {
        return savedCodes.keys.contains(code)
    }

    // Retrieve image from cache by barcode
    func retrieveImagePath(code: String) -> String? {
        return savedCodes[code]
    }

    func clearCache() {
        savedCodes.removeAll()

        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let barcodeDirectory = documentDirectory.appendingPathComponent("barcode_images")
                guard fileManager.fileExists(atPath: barcodeDirectory.path) else {
                    print("Directory does not exist: \(barcodeDirectory.path)")
                    return
                }

                try fileManager.removeItem(at: barcodeDirectory)
            } catch {
                print("Error clearing cache: \(error)")
            }
        }
    }

    func storeImageToCache(image: UIImage, code: String) {
        if isImageSaved(code: code) {
            return
        }

        // Convert UIImage to JPEG Data
        guard let jpegBytes = image.jpegData(compressionQuality: 1.0) else {
            print("Error converting image to JPEG")
            return
        }

        storeImage(imageBytes: jpegBytes, key: code)
    }
}
