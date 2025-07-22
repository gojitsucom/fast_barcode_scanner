package com.jhoogstraat.fast_barcode_scanner

import com.google.mlkit.vision.barcode.common.Barcode
import com.jhoogstraat.fast_barcode_scanner.pigeon.*

// MARK: - Resolution Extensions
val ResolutionEnum.width: Int
    get() = when (this) {
        ResolutionEnum.SD480 -> 720
        ResolutionEnum.HD720 -> 1280
        ResolutionEnum.HD1080 -> 1920
        ResolutionEnum.HD4K -> 3840
    }

val ResolutionEnum.height: Int
    get() = when (this) {
        ResolutionEnum.SD480 -> 480
        ResolutionEnum.HD720 -> 720
        ResolutionEnum.HD1080 -> 1080
        ResolutionEnum.HD4K -> 2160
    }

// MARK: - Framerate Extensions
val FramerateEnum.value: Double
    get() = when (this) {
        FramerateEnum.FPS30 -> 30.0
        FramerateEnum.FPS60 -> 60.0
        FramerateEnum.FPS120 -> 120.0
        FramerateEnum.FPS240 -> 240.0
    }

// MARK: - BarcodeType Mappings
val barcodeTypeToMLKit: Map<BarcodeTypeEnum, Int> = mapOf(
    BarcodeTypeEnum.AZTEC to Barcode.FORMAT_AZTEC,
    BarcodeTypeEnum.CODE128 to Barcode.FORMAT_CODE_128,
    BarcodeTypeEnum.CODE39 to Barcode.FORMAT_CODE_39,
    BarcodeTypeEnum.CODE93 to Barcode.FORMAT_CODE_93,
    BarcodeTypeEnum.CODABAR to Barcode.FORMAT_CODABAR,
    BarcodeTypeEnum.DATAMATRIX to Barcode.FORMAT_DATA_MATRIX,
    BarcodeTypeEnum.EAN13 to Barcode.FORMAT_EAN_13,
    BarcodeTypeEnum.EAN8 to Barcode.FORMAT_EAN_8,
    BarcodeTypeEnum.ITF to Barcode.FORMAT_ITF,
    BarcodeTypeEnum.PDF417 to Barcode.FORMAT_PDF417,
    BarcodeTypeEnum.QR to Barcode.FORMAT_QR_CODE,
    BarcodeTypeEnum.UPCA to Barcode.FORMAT_UPC_A,
    BarcodeTypeEnum.UPCE to Barcode.FORMAT_UPC_E
)

val mlKitToBarcodeType: Map<Int, BarcodeTypeEnum> = barcodeTypeToMLKit.entries.associate { (k, v) -> v to k }

// MARK: - BarcodeType Extensions
val BarcodeTypeEnum.mlKitFormat: Int?
    get() = barcodeTypeToMLKit[this]

fun Int.toBarcodeType(): BarcodeTypeEnum? = mlKitToBarcodeType[this]

// MARK: - BarcodeValueType Mappings
val barcodeValueTypeToMLKit: Map<BarcodeValueTypeEnum, Int> = mapOf(
    BarcodeValueTypeEnum.UNKNOWN to Barcode.TYPE_UNKNOWN,
    BarcodeValueTypeEnum.CONTACTINFO to Barcode.TYPE_CONTACT_INFO,
    BarcodeValueTypeEnum.EMAIL to Barcode.TYPE_EMAIL,
    BarcodeValueTypeEnum.ISBN to Barcode.TYPE_ISBN,
    BarcodeValueTypeEnum.PHONE to Barcode.TYPE_PHONE,
    BarcodeValueTypeEnum.PRODUCT to Barcode.TYPE_PRODUCT,
    BarcodeValueTypeEnum.SMS to Barcode.TYPE_SMS,
    BarcodeValueTypeEnum.TEXT to Barcode.TYPE_TEXT,
    BarcodeValueTypeEnum.URL to Barcode.TYPE_URL,
    BarcodeValueTypeEnum.WIFI to Barcode.TYPE_WIFI,
    BarcodeValueTypeEnum.GEO to Barcode.TYPE_GEO,
    BarcodeValueTypeEnum.CALENDER to Barcode.TYPE_CALENDAR_EVENT,
    BarcodeValueTypeEnum.LICENSE to Barcode.TYPE_DRIVER_LICENSE
)

val mlKitToBarcodeValueType: Map<Int, BarcodeValueTypeEnum> = barcodeValueTypeToMLKit.entries.associate { (k, v) -> v to k }

fun Int.toBarcodeValueType(): BarcodeValueTypeEnum? = mlKitToBarcodeValueType[this]

// MARK: - ScannerConfiguration Extensions
fun ScannerConfigurationData.copy(
    types: List<BarcodeTypeEnum?>? = null,
    mode: DetectionModeEnum? = null,
    resolution: ResolutionEnum? = null,
    framerate: FramerateEnum? = null,
    position: CameraPositionEnum? = null,
    apiMode: IOSApiModeEnum? = null,
    confidence: Double? = null
): ScannerConfigurationData {
    return ScannerConfigurationData(
        types = types ?: this.types,
        mode = mode ?: this.mode,
        resolution = resolution ?: this.resolution,
        framerate = framerate ?: this.framerate,
        position = position ?: this.position,
        apiMode = apiMode ?: this.apiMode,
        confidence = confidence ?: this.confidence
    )
}

// MARK: - PreviewConfiguration Extensions
val PreviewConfigurationData.analysisResolution: String
    get() = "${analysisWidth}x${analysisHeight}"

// MARK: - Utility Functions
fun createPreviewConfiguration(
    textureId: Long,
    targetRotation: Long,
    width: Long,
    height: Long
): PreviewConfigurationData {
    return PreviewConfigurationData(
        textureId = textureId,
        targetRotation = targetRotation,
        height = height,
        width = width,
        analysisWidth = width,
        analysisHeight = height
    )
}

// MARK: - MLKit Barcode to Pigeon Conversion
fun Barcode.toPigeonBarcode(): BarcodeData? {
    val type = this.format.toBarcodeType() ?: return null
    val valueType = this.valueType.toBarcodeValueType()
    
    val cornerPoints = this.cornerPoints?.map { point ->
        PointData(x = point.x.toLong(), y = point.y.toLong())
    }
    
    return BarcodeData(
        type = type,
        value = this.rawValue ?: "",
        valueType = valueType,
        cornerPoints = cornerPoints
    )
}

// MARK: - Error Handling
sealed class ScannerException(message: String) : Exception(message) {
    object InvalidConfiguration : ScannerException("Invalid scanner configuration")
    object CameraNotAvailable : ScannerException("Camera not available")
    object PermissionDenied : ScannerException("Camera permission denied")
    class Unknown(message: String) : ScannerException("Unknown error: $message")
}
