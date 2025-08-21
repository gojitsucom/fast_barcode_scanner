package com.jhoogstraat.fast_barcode_scanner

import com.google.mlkit.vision.barcode.common.Barcode
import com.jhoogstraat.fast_barcode_scanner.pigeon.*

// MARK: - Resolution Extensions
val Resolution.width: Int
    get() = when (this) {
        Resolution.SD480 -> 640
        Resolution.HD720 -> 1280
        Resolution.HD1080 -> 1920
        Resolution.HD4K -> 3840
    }

val Resolution.height: Int
    get() = when (this) {
        Resolution.SD480 -> 480
        Resolution.HD720 -> 720
        Resolution.HD1080 -> 1080
        Resolution.HD4K -> 2160
    }

// MARK: - Framerate Extensions
val Framerate.value: Double
    get() = when (this) {
        Framerate.FPS30 -> 30.0
        Framerate.FPS60 -> 60.0
        Framerate.FPS120 -> 120.0
        Framerate.FPS240 -> 240.0
    }

// MARK: - BarcodeType Mappings
val barcodeTypeToMLKit: Map<BarcodeType, Int> = mapOf(
    BarcodeType.AZTEC to Barcode.FORMAT_AZTEC,
    BarcodeType.CODE128 to Barcode.FORMAT_CODE_128,
    BarcodeType.CODE39 to Barcode.FORMAT_CODE_39,
    BarcodeType.CODE93 to Barcode.FORMAT_CODE_93,
    BarcodeType.CODABAR to Barcode.FORMAT_CODABAR,
    BarcodeType.DATA_MATRIX to Barcode.FORMAT_DATA_MATRIX,
    BarcodeType.EAN13 to Barcode.FORMAT_EAN_13,
    BarcodeType.EAN8 to Barcode.FORMAT_EAN_8,
    BarcodeType.ITF to Barcode.FORMAT_ITF,
    BarcodeType.PDF417 to Barcode.FORMAT_PDF417,
    BarcodeType.QR to Barcode.FORMAT_QR_CODE,
    BarcodeType.UPC_A to Barcode.FORMAT_UPC_A,
    BarcodeType.UPC_E to Barcode.FORMAT_UPC_E
)

val mlKitToBarcodeType: Map<Int, BarcodeType> = barcodeTypeToMLKit.entries.associate { (k, v) -> v to k }

// MARK: - BarcodeType Extensions
val BarcodeType.mlKitFormat: Int?
    get() = barcodeTypeToMLKit[this]

fun Int.toBarcodeType(): BarcodeType? = mlKitToBarcodeType[this]

// MARK: - BarcodeValueType Mappings
val barcodeValueTypeToMLKit: Map<BarcodeValueType, Int> = mapOf(
    BarcodeValueType.UNKNOWN to Barcode.TYPE_UNKNOWN,
    BarcodeValueType.CONTACT_INFO to Barcode.TYPE_CONTACT_INFO,
    BarcodeValueType.EMAIL to Barcode.TYPE_EMAIL,
    BarcodeValueType.ISBN to Barcode.TYPE_ISBN,
    BarcodeValueType.PHONE to Barcode.TYPE_PHONE,
    BarcodeValueType.PRODUCT to Barcode.TYPE_PRODUCT,
    BarcodeValueType.SMS to Barcode.TYPE_SMS,
    BarcodeValueType.TEXT to Barcode.TYPE_TEXT,
    BarcodeValueType.URL to Barcode.TYPE_URL,
    BarcodeValueType.WIFI to Barcode.TYPE_WIFI,
    BarcodeValueType.GEO to Barcode.TYPE_GEO,
    BarcodeValueType.CALENDER to Barcode.TYPE_CALENDAR_EVENT,
    BarcodeValueType.LICENSE to Barcode.TYPE_DRIVER_LICENSE
)

val mlKitToBarcodeValueType: Map<Int, BarcodeValueType> = barcodeValueTypeToMLKit.entries.associate { (k, v) -> v to k }

fun Int.toBarcodeValueType(): BarcodeValueType? = mlKitToBarcodeValueType[this]

// MARK: - ScannerConfiguration Extensions
fun ScannerConfiguration.copy(
    types: List<BarcodeType?>? = null,
    mode: DetectionMode? = null,
    resolution: Resolution? = null,
    framerate: Framerate? = null,
    position: CameraPosition? = null,
    apiMode: IOSApiMode? = null,
    confidence: Double? = null
): ScannerConfiguration {
    return ScannerConfiguration(
        types = types ?: this.types,
        mode = mode ?: this.mode,
        resolution = resolution ?: this.resolution,
        framerate = framerate ?: this.framerate,
        position = position ?: this.position,
        apiMode = apiMode ?: this.apiMode,
        confidence = confidence ?: this.confidence
    )
}

fun ScannerConfiguration.toMap(): HashMap<String, Any> {
    val map = HashMap<String, Any>()

    val typeStrings = types.mapNotNull { type ->
        when (type) {
            BarcodeType.AZTEC -> "aztec"
            BarcodeType.CODE128 -> "code128"
            BarcodeType.CODE39 -> "code39"
            BarcodeType.CODE93 -> "code93"
            BarcodeType.CODABAR -> "codabar"
            BarcodeType.DATA_MATRIX -> "dataMatrix"
            BarcodeType.EAN13 -> "ean13"
            BarcodeType.EAN8 -> "ean8"
            BarcodeType.ITF -> "itf"
            BarcodeType.PDF417 -> "pdf417"
            BarcodeType.QR -> "qr"
            BarcodeType.UPC_A -> "upcA"
            BarcodeType.UPC_E -> "upcE"
            BarcodeType.INTERLEAVED -> "interleaved"
            else -> null
        }
    }
    map["types"] = typeStrings

    val modeString = when (mode) {
        DetectionMode.PAUSE_DETECTION -> "pauseDetection"
        DetectionMode.PAUSE_VIDEO -> "pauseVideo"
        DetectionMode.CONTINUOUS -> "continuous"
    }
    map["detectionMode"] = modeString

    val resolutionString = when (resolution) {
        Resolution.SD480 -> "sd480"
        Resolution.HD720 -> "hd720"
        Resolution.HD1080 -> "hd1080"
        Resolution.HD4K -> "hd4k"
    }
    map["resolution"] = resolutionString

    val framerateString = when (framerate) {
        Framerate.FPS30 -> "fps30"
        Framerate.FPS60 -> "fps60"
        Framerate.FPS120 -> "fps120"
        Framerate.FPS240 -> "fps240"
    }
    map["framerate"] = framerateString

    val positionString = when (position) {
        CameraPosition.FRONT -> "front"
        CameraPosition.BACK -> "back"
    }
    map["position"] = positionString

    confidence?.let { map["confidence"] = it }

    return map
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
fun Resolution.portrait(): android.util.Size {
    return android.util.Size(height, width)
}

fun UpdateConfiguration.toMap(): HashMap<String, Any> {
    val map = HashMap<String, Any>()

    types?.let { typesList ->
        val typeStrings = typesList.mapNotNull { type ->
            when (type) {
                BarcodeType.AZTEC -> "aztec"
                BarcodeType.CODE128 -> "code128"
                BarcodeType.CODE39 -> "code39"
                BarcodeType.CODE93 -> "code93"
                BarcodeType.CODABAR -> "codabar"
                BarcodeType.DATA_MATRIX -> "dataMatrix"
                BarcodeType.EAN13 -> "ean13"
                BarcodeType.EAN8 -> "ean8"
                BarcodeType.ITF -> "itf"
                BarcodeType.PDF417 -> "pdf417"
                BarcodeType.QR -> "qr"
                BarcodeType.UPC_A -> "upcA"
                BarcodeType.UPC_E -> "upcE"
                BarcodeType.INTERLEAVED -> "interleaved"
                else -> null
            }
        }
        map["types"] = typeStrings
    }

    mode?.let { detectionMode ->
        val modeString = when (detectionMode) {
            DetectionMode.PAUSE_DETECTION -> "pauseDetection"
            DetectionMode.PAUSE_VIDEO -> "pauseVideo"
            DetectionMode.CONTINUOUS -> "continuous"
        }
        map["detectionMode"] = modeString
    }

    resolution?.let { res ->
        val resolutionString = when (res) {
            Resolution.SD480 -> "sd480"
            Resolution.HD720 -> "hd720"
            Resolution.HD1080 -> "hd1080"
            Resolution.HD4K -> "hd4k"
        }
        map["resolution"] = resolutionString
    }

    framerate?.let { fps ->
        val framerateString = when (fps) {
            Framerate.FPS30 -> "fps30"
            Framerate.FPS60 -> "fps60"
            Framerate.FPS120 -> "fps120"
            Framerate.FPS240 -> "fps240"
        }
        map["framerate"] = framerateString
    }

    position?.let { pos ->
        val positionString = when (pos) {
            CameraPosition.FRONT -> "front"
            CameraPosition.BACK -> "back"
        }
        map["position"] = positionString
    }

    return map
}
