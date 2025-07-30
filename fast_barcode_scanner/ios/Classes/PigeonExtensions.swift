import AVFoundation
import Vision

// MARK: - Resolution Extensions
extension Resolution {
    var width: Int32 {
        switch self {
        case .sd480: return 720
        case .hd720: return 1280
        case .hd1080: return 1920
        case .hd4k: return 3840
        }
    }

    var height: Int32 {
        switch self {
        case .sd480: return 480
        case .hd720: return 720
        case .hd1080: return 1080
        case .hd4k: return 2160
        }
    }
}

// MARK: - Framerate Extensions
extension Framerate {
    var doubleValue: Double {
        switch self {
        case .fps30: return 30
        case .fps60: return 60
        case .fps120: return 120
        case .fps240: return 240
        }
    }
}

// MARK: - CameraPosition Extensions
extension CameraPosition {
    var avCapturePosition: AVCaptureDevice.Position {
        switch self {
        case .front: return .front
        case .back: return .back
        }
    }
}

// MARK: - IOSApiMode Extensions
extension IOSApiMode {
    var stringValue: String {
        switch self {
        case .avFoundation: return "avFoundation"
        case .vision: return "vision"
        }
    }
}

// MARK: - BarcodeType Mappings

// Flutter -> AVFoundation
var avMetadataObjectTypes: [BarcodeType: AVMetadataObject.ObjectType] = {
    var types: [BarcodeType: AVMetadataObject.ObjectType] = [
        .aztec: .aztec,
        .code128: .code128,
        .code39: .code39,
        .code39mod43: .code39Mod43,
        .code93: .code93,
        .dataMatrix: .dataMatrix,
        .ean13: .ean13,
        .ean8: .ean8,
        .itf: .itf14,
        .pdf417: .pdf417,
        .qr: .qr,
        .upcA: .ean13, // UPC-A is reported as EAN-13
        .upcE: .upce,
        .interleaved: .interleaved2of5
    ]

    // Add codabar only if available (iOS 15.4+)
    if #available(iOS 15.4, *) {
        types[.codabar] = .codabar
    }

    return types
}()

// Flutter -> Vision
@available(iOS 11, *)
let vnBarcodeSymbols: [BarcodeType: VNBarcodeSymbology] = [
    .aztec: .aztec,
    .code128: .code128,
    .code39: .code39,
    .code93: .code93,
    .dataMatrix: .dataMatrix,
    .ean13: .ean13,
    .ean8: .ean8,
    .itf: .itf14,
    .pdf417: .pdf417,
    .qr: .qr,
    .upcE: .upce,
    .interleaved: .i2of5
]

// AVFoundation -> Flutter
let flutterMetadataObjectTypes: [AVMetadataObject.ObjectType: BarcodeType] = {
    var result: [AVMetadataObject.ObjectType: BarcodeType] = [:]
    for (barcodeType, objectType) in avMetadataObjectTypes {
        // For duplicate values, prefer the first one (ean13 over upcA)
        if result[objectType] == nil {
            result[objectType] = barcodeType
        }
    }
    return result
}()

// Vision -> Flutter
@available(iOS 11, *)
let flutterVNSymbols = Dictionary(uniqueKeysWithValues: vnBarcodeSymbols.map {
    ($1, $0)
})

// MARK: - BarcodeType Extensions
extension BarcodeType {
    var avMetadataObjectType: AVMetadataObject.ObjectType? {
        return avMetadataObjectTypes[self]
    }

    @available(iOS 11, *)
    var vnBarcodeSymbology: VNBarcodeSymbology? {
        return vnBarcodeSymbols[self]
    }

    func toInternalBarcodeType() -> String {
        switch self {
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
}

// MARK: - ScannerConfiguration Extensions
extension ScannerConfiguration {
    func copy(
        types: [BarcodeType?]? = nil,
        mode: DetectionMode? = nil,
        resolution: Resolution? = nil,
        framerate: Framerate? = nil,
        position: CameraPosition? = nil,
        apiMode: IOSApiMode? = nil,
        confidence: Double? = nil
    ) -> ScannerConfiguration {
        return ScannerConfiguration(
            types: types ?? self.types,
            mode: mode ?? self.mode,
            resolution: resolution ?? self.resolution,
            framerate: framerate ?? self.framerate,
            position: position ?? self.position,
            apiMode: apiMode ?? self.apiMode,
            confidence: confidence ?? self.confidence
        )
    }
}

// MARK: - PreviewConfiguration Extensions
extension PreviewConfiguration {
    var analysisResolution: String {
        return "\(analysisWidth)x\(analysisHeight)"
    }
}

// MARK: - Utility Functions
func createPreviewConfiguration(
    textureId: Int64,
    targetRotation: Int64,
    width: Int64,
    height: Int64
) -> PreviewConfiguration {
    return PreviewConfiguration(
        textureId: textureId,
        targetRotation: targetRotation,
        height: height,
        width: width,
        analysisWidth: width,
        analysisHeight: height
    )
}

// MARK: - Type Conversion Extensions

extension ScannerConfiguration {
    func toInternalScannerConfiguration() -> ScannerConfiguration {
        // For now, return self as the types are compatible
        // This is where we would convert if the internal types were different
        return self
    }

    func copy(with updateConfig: UpdateConfiguration) -> ScannerConfiguration {
        return ScannerConfiguration(
            types: updateConfig.types ?? self.types,
            mode: updateConfig.mode ?? self.mode,
            resolution: updateConfig.resolution ?? self.resolution,
            framerate: updateConfig.framerate ?? self.framerate,
            position: updateConfig.position ?? self.position,
            apiMode: self.apiMode,
            confidence: self.confidence
        )
    }

    // Compatibility properties for existing code
    var codes: [String] {
        return types.compactMap { $0?.toInternalBarcodeType() }
    }

    var detectionMode: DetectionMode {
        return mode
    }

    var cameraPosition: AVCaptureDevice.Position {
        return self.position.avCapturePosition
    }
}

extension PreviewConfiguration {
    func toPigeonPreviewConfiguration() -> PreviewConfiguration {
        // Return self as the types are already Pigeon types
        return self
    }
}

// MARK: - Barcode Data Conversion
func convertToPigeonBarcodeData(_ barcodeData: Any) -> BarcodeData? {
    guard let barcodeArray = barcodeData as? [Any?],
          barcodeArray.count >= 4 else {
        return nil
    }

    // Convert from [type, value, valueType, pointList] format
    // First try BarcodeType, then try String for backward compatibility
    let barcodeType: BarcodeType
    if let type = barcodeArray[0] as? BarcodeType {
        barcodeType = type
    } else if let typeString = barcodeArray[0] as? String,
              let type = BarcodeType.fromString(typeString) {
        barcodeType = type
    } else {
        return nil
    }

    guard let value = barcodeArray[1] as? String else {
        return nil
    }

    // Convert point list to PointData array
    var cornerPoints: [PointData?]?
    if let pointList = barcodeArray[3] as? [[Int]], !pointList.isEmpty {
        cornerPoints = pointList.map { point in
            guard point.count >= 2 else { return nil }
            return PointData(x: Int64(point[0]), y: Int64(point[1]))
        }
    }

    return BarcodeData(
        type: barcodeType,
        value: value,
        valueType: nil, // iOS doesn't provide value type
        cornerPoints: cornerPoints
    )
}

extension BarcodeType {
    static func fromString(_ typeString: String) -> BarcodeType? {
        switch typeString {
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
        default: return nil
        }
    }
}

// MARK: - Error Handling
enum ScannerError: Error {
    case invalidConfiguration
    case cameraNotAvailable
    case permissionDenied
    case unknown(String)
    case notInitialized
    case invalidArguments(Any?)
    case loadingDataFailed
    case configurationError(String)
    case unauthorized
    case noInputDeviceForConfig(ScannerConfiguration)
    case cameraNotSuitable

    var localizedDescription: String {
        switch self {
        case .invalidConfiguration:
            return "Invalid scanner configuration"
        case .cameraNotAvailable:
            return "Camera not available"
        case .permissionDenied:
            return "Camera permission denied"
        case .notInitialized:
            return "Scanner not initialized"
        case .invalidArguments(let args):
            return "Invalid arguments: \(String(describing: args))"
        case .loadingDataFailed:
            return "Failed to load image data"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .unauthorized:
            return "Camera access unauthorized"
        case .noInputDeviceForConfig(let config):
            return "No input device available for configuration: \(config)"
        case .cameraNotSuitable:
            return "Camera not suitable for configuration"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
