import AVFoundation
import Vision

// MARK: - Resolution Extensions
extension ResolutionEnum {
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
extension FramerateEnum {
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
extension CameraPositionEnum {
    var avCapturePosition: AVCaptureDevice.Position {
        switch self {
        case .front: return .front
        case .back: return .back
        }
    }
}

// MARK: - IOSApiMode Extensions
extension IOSApiModeEnum {
    var stringValue: String {
        switch self {
        case .avFoundation: return "avFoundation"
        case .vision: return "vision"
        }
    }
}

// MARK: - BarcodeType Mappings

// Flutter -> AVFoundation
let avMetadataObjectTypes: [BarcodeTypeEnum: AVMetadataObject.ObjectType] = [
    .aztec: .aztec,
    .code128: .code128,
    .code39: .code39,
    .code39mod43: .code39Mod43,
    .code93: .code93,
    .codabar: .codabar,
    .dataMatrix: .dataMatrix,
    .ean13: .ean13,
    .ean8: .ean8,
    .itf: .itf14,
    .pdf417: .pdf417,
    .qr: .qr,
    .upcA: .upca,
    .upcE: .upce,
    .interleaved: .interleaved2of5
]

// Flutter -> Vision
@available(iOS 11, *)
let vnBarcodeSymbols: [BarcodeTypeEnum: VNBarcodeSymbology] = [
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
let flutterMetadataObjectTypes = Dictionary(uniqueKeysWithValues: avMetadataObjectTypes.map {
    ($1, $0)
})

// Vision -> Flutter
@available(iOS 11, *)
let flutterVNSymbols = Dictionary(uniqueKeysWithValues: vnBarcodeSymbols.map {
    ($1, $0)
})

// MARK: - BarcodeType Extensions
extension BarcodeTypeEnum {
    var avMetadataObjectType: AVMetadataObject.ObjectType? {
        return avMetadataObjectTypes[self]
    }
    
    @available(iOS 11, *)
    var vnBarcodeSymbology: VNBarcodeSymbology? {
        return vnBarcodeSymbols[self]
    }
}

// MARK: - ScannerConfiguration Extensions
extension ScannerConfigurationData {
    func copy(
        types: [BarcodeTypeEnum?]? = nil,
        mode: DetectionModeEnum? = nil,
        resolution: ResolutionEnum? = nil,
        framerate: FramerateEnum? = nil,
        position: CameraPositionEnum? = nil,
        apiMode: IOSApiModeEnum? = nil,
        confidence: Double? = nil
    ) -> ScannerConfigurationData {
        return ScannerConfigurationData(
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
extension PreviewConfigurationData {
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
) -> PreviewConfigurationData {
    return PreviewConfigurationData(
        textureId: textureId,
        targetRotation: targetRotation,
        height: height,
        width: width,
        analysisWidth: width,
        analysisHeight: height
    )
}

// MARK: - Error Handling
enum ScannerError: Error {
    case invalidConfiguration
    case cameraNotAvailable
    case permissionDenied
    case unknown(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidConfiguration:
            return "Invalid scanner configuration"
        case .cameraNotAvailable:
            return "Camera not available"
        case .permissionDenied:
            return "Camera permission denied"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
