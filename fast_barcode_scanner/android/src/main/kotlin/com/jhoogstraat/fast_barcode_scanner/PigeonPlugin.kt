package com.jhoogstraat.fast_barcode_scanner

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.MediaStore
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.jhoogstraat.fast_barcode_scanner.types.ScannerException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import java.io.IOException

/** PigeonFastBarcodeScannerPlugin */
class PigeonFastBarcodeScannerPlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener {
    private lateinit var context: Context
    private var activity: Activity? = null
    private var scanner: Scanner? = null
    private var flutterApi: BarcodeScannerFlutterApi? = null
    private var hostApi: BarcodeScannerHostApiImpl? = null
    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pickImageCompleter: com.google.android.gms.tasks.TaskCompletionSource<Uri?>? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        flutterApi = BarcodeScannerFlutterApi(flutterPluginBinding.binaryMessenger)
        hostApi = BarcodeScannerHostApiImpl(flutterPluginBinding, this)
        BarcodeScannerHostApi.setUp(flutterPluginBinding.binaryMessenger, hostApi)
        pluginBinding = flutterPluginBinding
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        flutterApi = null
        hostApi = null
        pluginBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    /* Activity Result Listener for picking images from Intent */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 1) {
            return false
        }

        val completer = pickImageCompleter ?: return false

        when (resultCode) {
            Activity.RESULT_OK -> {
                try {
                    completer.setResult(data?.data)
                } catch (e: IOException) {
                    completer.setException(ScannerException.LoadingFailed(e))
                }
            }

            else -> {
                completer.setResult(null)
            }
        }

        pickImageCompleter = null

        return true
    }

    inner class BarcodeScannerHostApiImpl(
        private val pluginBinding: FlutterPlugin.FlutterPluginBinding,
        private val plugin: PigeonFastBarcodeScannerPlugin
    ) : BarcodeScannerHostApi {
        
        override fun initialize(config: ScannerConfiguration): PreviewConfiguration {
            val currentActivity = activity ?: throw IllegalStateException("Activity is null")
            
            // Create scanner if it doesn't exist
            if (scanner == null) {
                scanner = Scanner(
                    currentActivity,
                    pluginBinding.textureRegistry.createSurfaceTexture(),
                    config.toNativeConfig()
                ) { barcodes ->
                    // Convert native barcodes to Pigeon barcodes
                    val pigeonBarcodes = barcodes.map { barcode ->
                        val cornerPoints = barcode.cornerPoints?.map { point ->
                            Point.Builder().setX(point.x).setY(point.y).build()
                        }
                        
                        BarcodeData.Builder()
                            .setType(barcode.format.toPigeonType())
                            .setValue(barcode.rawValue ?: "")
                            .setValueType(barcode.valueType.toPigeonValueType())
                            .setCornerPoints(cornerPoints)
                            .build()
                    }
                    
                    // Send barcodes to Flutter
                    flutterApi?.onBarcodeDetection(pigeonBarcodes)
                }
                
                activityBinding?.addRequestPermissionsResultListener(scanner!!)
            }
            
            // Initialize scanner
            val previewConfig = scanner!!.requestPermissions()
                .continueWith { scanner!!.loadCamera() }
                .getResult()
            
            // Convert native preview configuration to Pigeon type
            return PreviewConfiguration.Builder()
                .setWidth(previewConfig.width)
                .setHeight(previewConfig.height)
                .setTargetRotation(previewConfig.targetRotation)
                .setTextureId(previewConfig.textureId)
                .setAnalysisResolution(previewConfig.analysisResolution)
                .setAnalysisWidth(previewConfig.analysisWidth)
                .setAnalysisHeight(previewConfig.analysisHeight)
                .build()
        }

        override fun start() {
            scanner?.startCamera() ?: throw IllegalStateException("Scanner not initialized")
        }

        override fun stop() {
            scanner?.stopCamera()
        }

        override fun startDetector() {
            scanner?.startDetector() ?: throw IllegalStateException("Scanner not initialized")
        }

        override fun stopDetector() {
            scanner?.stopDetector()
        }

        override fun dispose() {
            scanner?.also {
                it.stopCamera()
                it.flutterTextureEntry.release()
                activityBinding?.removeRequestPermissionsResultListener(it)
            }
            
            scanner = null
        }

        override fun toggleTorch(): Boolean {
            val scanner = scanner ?: throw IllegalStateException("Scanner not initialized")
            
            scanner.toggleTorch()
                .addListener(
                    {},
                    ContextCompat.getMainExecutor(scanner.activity)
                )
            
            return scanner.torchState
        }

        override fun updateConfiguration(config: ScannerConfiguration): PreviewConfiguration {
            val scanner = scanner ?: throw IllegalStateException("Scanner not initialized")
            
            // Update scanner configuration
            val previewConfig = scanner.changeConfiguration(config.toNativeConfig())
            
            // Convert native preview configuration to Pigeon type
            return PreviewConfiguration.Builder()
                .setWidth(previewConfig.width)
                .setHeight(previewConfig.height)
                .setTargetRotation(previewConfig.targetRotation)
                .setTextureId(previewConfig.textureId)
                .setAnalysisResolution(previewConfig.analysisResolution)
                .setAnalysisWidth(previewConfig.analysisWidth)
                .setAnalysisHeight(previewConfig.analysisHeight)
                .build()
        }

        override fun scanImage(imageData: ImageData): List<BarcodeData>? {
            val options = BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS).build()
            val scanner = BarcodeScanning.getClient(options)
            
            val barcodes = if (imageData.bytes != null) {
                // Binary
                scanner.process(
                    InputImage.fromBitmap(
                        BitmapFactory.decodeByteArray(
                            imageData.bytes.toByteArray(),
                            0,
                            imageData.bytes.size
                        ),
                        imageData.rotation
                    )
                ).getResult()
            } else if (imageData.isFromPicker) {
                // Picker
                if (pickImageCompleter?.task?.isComplete == false)
                    throw ScannerException.AlreadyPicking()
                
                val activityBinding = activityBinding ?: throw ScannerException.ActivityNotConnected()
                
                val intent = Intent(
                    Intent.ACTION_PICK,
                    MediaStore.Images.Media.INTERNAL_CONTENT_URI
                )
                intent.type = "image/*"
                
                plugin.pickImageCompleter = com.google.android.gms.tasks.TaskCompletionSource<Uri?>()
                
                activityBinding.activity.startActivityForResult(intent, 1)
                
                val uri = plugin.pickImageCompleter!!.task.getResult()
                
                if (uri == null) null else
                    scanner.process(
                        InputImage.fromFilePath(
                            activityBinding.activity,
                            uri
                        )
                    ).getResult()
            } else {
                null
            }
            
            // Convert native barcodes to Pigeon barcodes
            return barcodes?.map { barcode ->
                val cornerPoints = barcode.cornerPoints?.map { point ->
                    Point.Builder().setX(point.x).setY(point.y).build()
                }
                
                BarcodeData.Builder()
                    .setType(barcode.format.toPigeonType())
                    .setValue(barcode.rawValue ?: "")
                    .setValueType(barcode.valueType.toPigeonValueType())
                    .setCornerPoints(cornerPoints)
                    .build()
            }
        }

        override fun retrieveCachedImage(code: String): String? {
            return ImageHelper.getInstance().retrieveImagePath(code)
        }

        override fun clearCachedImage() {
            val camera = scanner ?: throw ScannerException.NotInitialized()
            if (camera.activity.applicationContext != null) {
                ImageHelper.getInstance().clearCache(camera.activity.applicationContext!!)
            }
        }
        
        // Extension function to convert Pigeon configuration to native configuration
        private fun ScannerConfiguration.toNativeConfig(): HashMap<String, Any> {
            val map = HashMap<String, Any>()
            
            // Convert types
            map["types"] = types.map { it.toNativeTypeString() }
            
            // Convert resolution
            map["resolution"] = resolution.toNativeResolutionString()
            
            // Convert framerate
            map["framerate"] = framerate.toNativeFramerateString()
            
            // Convert detection mode
            map["detectionMode"] = detectionMode.toNativeDetectionModeString()
            
            // Convert position
            map["position"] = position.toNativeCameraPositionString()
            
            // Convert API mode config if present
            apiModeConfig?.let { config ->
                map["ios"] = mapOf(
                    "mode" to config.apiMode.toNativeApiModeString(),
                    "confidence" to config.confidence
                )
            }
            
            return map
        }
        
        // Extension functions to convert Pigeon types to native types
        private fun BarcodeType.toNativeTypeString(): String {
            return when (this) {
                BarcodeType.AZTEC -> "aztec"
                BarcodeType.CODE128 -> "code128"
                BarcodeType.CODE39 -> "code39"
                BarcodeType.CODE39MOD43 -> "code39mod43"
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
            }
        }
        
        private fun Resolution.toNativeResolutionString(): String {
            return when (this) {
                Resolution.SD480 -> "sd480"
                Resolution.HD720 -> "hd720"
                Resolution.HD1080 -> "hd1080"
                Resolution.HD4K -> "hd4k"
            }
        }
        
        private fun Framerate.toNativeFramerateString(): String {
            return when (this) {
                Framerate.FPS30 -> "fps30"
                Framerate.FPS60 -> "fps60"
                Framerate.FPS120 -> "fps120"
                Framerate.FPS240 -> "fps240"
            }
        }
        
        private fun DetectionMode.toNativeDetectionModeString(): String {
            return when (this) {
                DetectionMode.PAUSE_DETECTION -> "pauseDetection"
                DetectionMode.PAUSE_VIDEO -> "pauseVideo"
                DetectionMode.CONTINUOUS -> "continuous"
            }
        }
        
        private fun CameraPosition.toNativeCameraPositionString(): String {
            return when (this) {
                CameraPosition.FRONT -> "front"
                CameraPosition.BACK -> "back"
            }
        }
        
        private fun ApiMode.toNativeApiModeString(): String {
            return when (this) {
                ApiMode.AV_FOUNDATION -> "avFoundation"
                ApiMode.VISION -> "vision"
            }
        }
        
        // Extension functions to convert native types to Pigeon types
        private fun Int.toPigeonType(): BarcodeType {
            return when (this) {
                Barcode.FORMAT_AZTEC -> BarcodeType.AZTEC
                Barcode.FORMAT_CODE_128 -> BarcodeType.CODE128
                Barcode.FORMAT_CODE_39 -> BarcodeType.CODE39
                Barcode.FORMAT_CODE_93 -> BarcodeType.CODE93
                Barcode.FORMAT_CODABAR -> BarcodeType.CODABAR
                Barcode.FORMAT_DATA_MATRIX -> BarcodeType.DATA_MATRIX
                Barcode.FORMAT_EAN_13 -> BarcodeType.EAN13
                Barcode.FORMAT_EAN_8 -> BarcodeType.EAN8
                Barcode.FORMAT_ITF -> BarcodeType.ITF
                Barcode.FORMAT_PDF417 -> BarcodeType.PDF417
                Barcode.FORMAT_QR_CODE -> BarcodeType.QR
                Barcode.FORMAT_UPC_A -> BarcodeType.UPC_A
                Barcode.FORMAT_UPC_E -> BarcodeType.UPC_E
                else -> BarcodeType.QR // Default to QR
            }
        }
        
        private fun Int.toPigeonValueType(): BarcodeValueType {
            return when (this) {
                Barcode.TYPE_CONTACT_INFO -> BarcodeValueType.CONTACT_INFO
                Barcode.TYPE_EMAIL -> BarcodeValueType.EMAIL
                Barcode.TYPE_ISBN -> BarcodeValueType.ISBN
                Barcode.TYPE_PHONE -> BarcodeValueType.PHONE
                Barcode.TYPE_PRODUCT -> BarcodeValueType.PRODUCT
                Barcode.TYPE_SMS -> BarcodeValueType.SMS
                Barcode.TYPE_TEXT -> BarcodeValueType.TEXT
                Barcode.TYPE_URL -> BarcodeValueType.URL
                Barcode.TYPE_WIFI -> BarcodeValueType.WIFI
                Barcode.TYPE_GEO -> BarcodeValueType.GEO
                Barcode.TYPE_CALENDAR_EVENT -> BarcodeValueType.CALENDER
                Barcode.TYPE_DRIVER_LICENSE -> BarcodeValueType.LICENSE
                else -> BarcodeValueType.UNKNOWN
            }
        }
    }
}
