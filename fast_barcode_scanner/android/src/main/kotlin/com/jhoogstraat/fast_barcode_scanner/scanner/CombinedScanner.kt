package com.jhoogstraat.fast_barcode_scanner.scanner

import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.common.InputImage

interface OnDetectedListener<T> {
    fun onSuccess(codes: T, imageProxy: ImageProxy)
}

/**
 * Combined scanner that can detect both barcodes and text (OCR)
 */
class CombinedScanner(
    barcodeOptions: BarcodeScannerOptions?,
    private val includeOcr: Boolean,
    private val successListener: OnDetectedListener<CombinedResult>,
    private val failureListener: OnFailureListener
) : ImageAnalysis.Analyzer {
    
    private val barcodeScanner = if (barcodeOptions != null) {
        BarcodeScanning.getClient(barcodeOptions)
    } else null
    
    private val textRecognizer = if (includeOcr) {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    } else null

    @ExperimentalGetImage
    override fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            val inputImage = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
            val ocrImage = InputImage.fromMediaImage(mediaImage, 180)
            
            val tasks = mutableListOf<com.google.android.gms.tasks.Task<*>>()
            
            // Add barcode scanning task if scanner is available
            val barcodeTask = barcodeScanner?.process(inputImage)
            if (barcodeTask != null) {
                tasks.add(barcodeTask)
            }
            
            // Add text recognition task if OCR is enabled
            val textTask = textRecognizer?.process(ocrImage)
            if (textTask != null) {
                tasks.add(textTask)
            }
            
            // Wait for all tasks to complete
            Tasks.whenAllComplete(tasks)
                .addOnSuccessListener {
                    val barcodes = if (barcodeTask != null && barcodeTask.isSuccessful) {
                        barcodeTask.result ?: emptyList()
                    } else {
                        emptyList()
                    }
                    
                    val text = if (textTask != null && textTask.isSuccessful) {
                        textTask.result
                    } else {
                        null
                    }
                    
                    val result = CombinedResult(barcodes, text)
                    successListener.onSuccess(result, imageProxy)
                }
                .addOnFailureListener { exception ->
                    failureListener.onFailure(exception)
                    imageProxy.close()
                }
        } else {
            imageProxy.close()
        }
    }
}

/**
 * Result containing both barcode and OCR detections
 */
data class CombinedResult(
    val barcodes: List<Barcode>,
    val text: Text?
)

