package com.jhoogstraat.fast_barcode_scanner.types

import BarcodeType
import CameraPosition
import DetectionMode
import Framerate
import Resolution
import android.util.Size
import com.google.mlkit.vision.barcode.common.Barcode

data class ScannerConfiguration(
    val formats: IntArray,
    val mode: DetectionMode,
    val resolution: Resolution,
    val framerate: Framerate,
    val position: CameraPosition
)

// Extension functions for the generated enums
fun Framerate.intValue(): Int = when (this) {
    Framerate.FPS30 -> 30
    Framerate.FPS60 -> 60
    Framerate.FPS120 -> 120
    Framerate.FPS240 -> 240
}

fun Framerate.duration(): Long = 1 / intValue().toLong()

fun Resolution.width(): Int = when (this) {
    Resolution.SD480 -> 640
    Resolution.HD720 -> 1280
    Resolution.HD1080 -> 1920
    Resolution.HD4K -> 3840
}

fun Resolution.height(): Int = when (this) {
    Resolution.SD480 -> 480
    Resolution.HD720 -> 720
    Resolution.HD1080 -> 1080
    Resolution.HD4K -> 2160
}

fun Resolution.landscape(): Size = Size(width(), height())
fun Resolution.portrait(): Size = Size(height(), width())

val barcodeFormatMap = hashMapOf(
    "aztec" to Barcode.FORMAT_AZTEC,
    "code128" to Barcode.FORMAT_CODE_128,
    "code39" to Barcode.FORMAT_CODE_39,
    "code93" to Barcode.FORMAT_CODE_93,
    "codabar" to Barcode.FORMAT_CODABAR,
    "dataMatrix" to Barcode.FORMAT_DATA_MATRIX,
    "ean13" to Barcode.FORMAT_EAN_13,
    "ean8" to Barcode.FORMAT_EAN_8,
    "itf" to Barcode.FORMAT_ITF,
    "pdf417" to Barcode.FORMAT_PDF417,
    "qr" to Barcode.FORMAT_QR_CODE,
    "upcA" to Barcode.FORMAT_UPC_A,
    "upcE" to Barcode.FORMAT_UPC_E
)

val barcodeStringMap = barcodeFormatMap.entries.associateBy({ it.value }) { it.key }