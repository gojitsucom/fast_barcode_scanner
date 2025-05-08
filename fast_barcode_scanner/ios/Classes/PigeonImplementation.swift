import Flutter
import UIKit
import AVFoundation
import Vision

@objc public class PigeonImplementation: NSObject, BarcodeScannerHostApi {
    private var scanner: Scanner?
    private var flutterApi: BarcodeScannerFlutterApi?
    
    init(binaryMessenger: FlutterBinaryMessenger) {
        super.init()
        self.flutterApi = BarcodeScannerFlutterApi(binaryMessenger: binaryMessenger)
        BarcodeScannerHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: self)
    }
    
    // MARK: - BarcodeScannerHostApi Implementation
    
    public func initialize(config: ScannerConfiguration) throws -> PreviewConfiguration {
        // Create scanner if it doesn't exist
        if scanner == nil {
            scanner = Scanner()
            scanner?.onBarcodeDetection = { [weak self] barcodes in
                // Convert native barcodes to Pigeon barcodes
                let pigeonBarcodes = barcodes.map { barcode -> BarcodeData in
                    let cornerPoints = barcode.cornerPoints?.map { point -> Point in
                        return Point(x: Int64(point.x), y: Int64(point.y))
                    }
                    
                    return BarcodeData(
                        type: self?.convertToBarcodePigeonType(barcode.type) ?? .qr,
                        value: barcode.value,
                        valueType: self?.convertToBarcodePigeonValueType(barcode.valueType),
                        cornerPoints: cornerPoints
                    )
                }
                
                // Send barcodes to Flutter
                self?.flutterApi?.onBarcodeDetection(barcodes: pigeonBarcodes) { _ in }
            }
            
            scanner?.onError = { [weak self] errorMessage in
                self?.flutterApi?.onError(errorMessage: errorMessage) { _ in }
            }
        }
        
        // Convert Pigeon configuration to native configuration
        let nativeConfig = convertToNativeConfig(config)
        
        // Initialize scanner
        let previewConfig = try scanner!.initialize(config: nativeConfig)
        
        // Convert native preview configuration to Pigeon type
        return PreviewConfiguration(
            width: Int64(previewConfig.width),
            height: Int64(previewConfig.height),
            targetRotation: Int64(previewConfig.targetRotation),
            textureId: Int64(previewConfig.textureId),
            analysisResolution: previewConfig.analysisResolution,
            analysisWidth: Int64(previewConfig.analysisWidth),
            analysisHeight: Int64(previewConfig.analysisHeight)
        )
    }
    
    public func start() throws {
        guard let scanner = scanner else {
            throw NSError(domain: "com.jhoogstraat.fast_barcode_scanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scanner not initialized"])
        }
        
        try scanner.start()
    }
    
    public func stop() throws {
        scanner?.stop()
    }
    
    public func startDetector() throws {
        guard let scanner = scanner else {
            throw NSError(domain: "com.jhoogstraat.fast_barcode_scanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scanner not initialized"])
        }
        
        try scanner.startDetector()
    }
    
    public func stopDetector() throws {
        scanner?.stopDetector()
    }
    
    public func dispose() throws {
        scanner?.dispose()
        scanner = nil
    }
    
    public func toggleTorch() throws -> Bool {
        guard let scanner = scanner else {
            throw NSError(domain: "com.jhoogstraat.fast_barcode_scanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scanner not initialized"])
        }
        
        return try scanner.toggleTorch()
    }
    
    public func updateConfiguration(config: ScannerConfiguration) throws -> PreviewConfiguration {
        guard let scanner = scanner else {
            throw NSError(domain: "com.jhoogstraat.fast_barcode_scanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scanner not initialized"])
        }
        
        // Convert Pigeon configuration to native configuration
        let nativeConfig = convertToNativeConfig(config)
        
        // Update scanner configuration
        let previewConfig = try scanner.updateConfiguration(config: nativeConfig)
        
        // Convert native preview configuration to Pigeon type
        return PreviewConfiguration(
            width: Int64(previewConfig.width),
            height: Int64(previewConfig.height),
            targetRotation: Int64(previewConfig.targetRotation),
            textureId: Int64(previewConfig.textureId),
            analysisResolution: previewConfig.analysisResolution,
            analysisWidth: Int64(previewConfig.analysisWidth),
            analysisHeight: Int64(previewConfig.analysisHeight)
        )
    }
    
    public func scanImage(imageData: ImageData) throws -> [BarcodeData]? {
        guard let scanner = scanner else {
            throw NSError(domain: "com.jhoogstraat.fast_barcode_scanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scanner not initialized"])
        }
        
        // Convert Pigeon image data to native image data
        let bytes = imageData.bytes
        let rotation = Int(imageData.rotation)
        let isFromPicker = imageData.isFromPicker
        
        // Scan image
        let barcodes = try scanner.scanImage(bytes: bytes, rotation: rotation, isFromPicker: isFromPicker)
        
        // Convert native barcodes to Pigeon barcodes
        return barcodes?.map { barcode in
            let cornerPoints = barcode.cornerPoints?.map { point -> Point in
                return Point(x: Int64(point.x), y: Int64(point.y))
            }
            
            return BarcodeData(
                type: convertToBarcodePigeonType(barcode.type),
                value: barcode.value,
                valueType: convertToBarcodePigeonValueType(barcode.valueType),
                cornerPoints: cornerPoints
            )
        }
    }
    
    public func retrieveCachedImage(code: String) throws -> String? {
        guard let scanner = scanner else {
            throw NSError(domain: "com.jhoogstraat.fast_barcode_scanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scanner not initialized"])
        }
        
        return scanner.retrieveCachedImage(code: code)
    }
    
    public func clearCachedImage() throws {
        guard let scanner = scanner else {
            throw NSError(domain: "com.jhoogstraat.fast_barcode_scanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scanner not initialized"])
        }
        
        scanner.clearCachedImage()
    }
    
    // MARK: - Helper Methods
    
    private func convertToNativeConfig(_ config: ScannerConfiguration) -> [String: Any] {
        var nativeConfig: [String: Any] = [:]
        
        // Convert types
        nativeConfig["types"] = config.types.map { convertToNativeTypeString($0) }
        
        // Convert resolution
        nativeConfig["resolution"] = convertToNativeResolutionString(config.resolution)
        
        // Convert framerate
        nativeConfig["framerate"] = convertToNativeFramerateString(config.framerate)
        
        // Convert detection mode
        nativeConfig["detectionMode"] = convertToNativeDetectionModeString(config.detectionMode)
        
        // Convert position
        nativeConfig["position"] = convertToNativeCameraPositionString(config.position)
        
        // Convert API mode config if present
        if let apiModeConfig = config.apiModeConfig {
            nativeConfig["ios"] = [
                "mode": convertToNativeApiModeString(apiModeConfig.apiMode),
                "confidence": apiModeConfig.confidence
            ]
        }
        
        return nativeConfig
    }
    
    private func convertToNativeTypeString(_ type: BarcodeType) -> String {
        switch type {
        case .aztec: return "aztec"
        case .code128: return "code128"
        case .code39: return "code39"
        case .code39mod43: return "code39mod43"
        case .code93: return "code93"
        case .codabar: return "codabar"
        case .dataMatrix: return "dataMatrix"
        case .ean13: return "ean13"
        case .ean8: return "ean8"
        case .itf: return "itf"
        case .pdf417: return "pdf417"
        case .qr: return "qr"
        case .upcA: return "upcA"
        case .upcE: return "upcE"
        case .interleaved: return "interleaved"
        }
    }
    
    private func convertToNativeResolutionString(_ resolution: Resolution) -> String {
        switch resolution {
        case .sd480: return "sd480"
        case .hd720: return "hd720"
        case .hd1080: return "hd1080"
        case .hd4k: return "hd4k"
        }
    }
    
    private func convertToNativeFramerateString(_ framerate: Framerate) -> String {
        switch framerate {
        case .fps30: return "fps30"
        case .fps60: return "fps60"
        case .fps120: return "fps120"
        case .fps240: return "fps240"
        }
    }
    
    private func convertToNativeDetectionModeString(_ mode: DetectionMode) -> String {
        switch mode {
        case .pauseDetection: return "pauseDetection"
        case .pauseVideo: return "pauseVideo"
        case .continuous: return "continuous"
        }
    }
    
    private func convertToNativeCameraPositionString(_ position: CameraPosition) -> String {
        switch position {
        case .front: return "front"
        case .back: return "back"
        }
    }
    
    private func convertToNativeApiModeString(_ mode: ApiMode) -> String {
        switch mode {
        case .avFoundation: return "avFoundation"
        case .vision: return "vision"
        }
    }
    
    private func convertToBarcodePigeonType(_ type: String) -> BarcodeType {
        switch type {
        case "aztec": return .aztec
        case "code128": return .code128
        case "code39": return .code39
        case "code39mod43": return .code39mod43
        case "code93": return .code93
        case "codabar": return .codabar
        case "dataMatrix": return .dataMatrix
        case "ean13": return .ean13
        case "ean8": return .ean8
        case "itf": return .itf
        case "pdf417": return .pdf417
        case "qr": return .qr
        case "upcA": return .upcA
        case "upcE": return .upcE
        case "interleaved": return .interleaved
        default: return .qr
        }
    }
    
    private func convertToBarcodePigeonValueType(_ type: String?) -> BarcodeValueType? {
        guard let type = type else { return nil }
        
        switch type {
        case "unknown": return .unknown
        case "contactInfo": return .contactInfo
        case "email": return .email
        case "isbn": return .isbn
        case "phone": return .phone
        case "product": return .product
        case "sms": return .sms
        case "text": return .text
        case "url": return .url
        case "wifi": return .wifi
        case "geo": return .geo
        case "calender": return .calender
        case "license": return .license
        default: return .unknown
        }
    }
}
