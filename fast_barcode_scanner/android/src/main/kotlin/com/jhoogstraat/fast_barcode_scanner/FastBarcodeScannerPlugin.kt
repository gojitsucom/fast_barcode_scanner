package com.jhoogstraat.fast_barcode_scanner

import ImageHelper
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.MediaStore
import androidx.core.content.ContextCompat
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.TaskCompletionSource
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.jhoogstraat.fast_barcode_scanner.pigeon.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import java.io.IOException

/** FastBarcodeScannerPlugin - Pigeon-based implementation */
class FastBarcodeScannerPlugin : FlutterPlugin, ActivityAware, 
    PluginRegistry.ActivityResultListener, FastBarcodeScannerHostApi {
    
    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var camera: Camera? = null
    private var flutterApi: FastBarcodeScannerFlutterApi? = null
    private var pickImageCompleter: TaskCompletionSource<Uri?>? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        pluginBinding = flutterPluginBinding
        
        // Set up Pigeon APIs
        FastBarcodeScannerHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
        flutterApi = FastBarcodeScannerFlutterApi(flutterPluginBinding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        FastBarcodeScannerHostApi.setUp(binding.binaryMessenger, null)
        pluginBinding = null
        flutterApi = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        dispose { }
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    // FastBarcodeScannerHostApi implementation
    override fun initialize(configuration: ScannerConfiguration, callback: (Result<PreviewConfiguration>) -> Unit) {
        try {
            if (this.camera != null) {
                this.camera!!.requestPermissions()
                    .continueWithTask { this.camera!!.loadCamera() }
                    .addOnSuccessListener { callback(Result.success(it)) }
                    .addOnFailureListener { callback(Result.failure(it)) }
                return
            }

            val pluginBinding = this.pluginBinding ?: throw ScannerException.ActivityNotConnected()
            val activityBinding = this.activityBinding ?: throw ScannerException.ActivityNotConnected()

            // Use Pigeon configuration directly

            val camera = Camera(
                activityBinding.activity,
                pluginBinding.textureRegistry.createSurfaceTexture(),
                configuration
            ) { scanData ->
                // ScanData is already in Pigeon format, send directly via FlutterApi
                flutterApi?.onScanDataDetected(scanData) { }
            }

            this.camera = camera
            activityBinding.addRequestPermissionsResultListener(camera)

            camera.requestPermissions()
                .continueWithTask { camera.loadCamera() }
                .addOnSuccessListener { callback(Result.success(it)) }
                .addOnFailureListener { callback(Result.failure(it)) }

        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun start(callback: (Result<Unit>) -> Unit) {
        try {
            val camera = this.camera ?: throw ScannerException.NotInitialized()
            camera.startCamera()
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun stop(callback: (Result<Unit>) -> Unit) {
        try {
            val camera = this.camera ?: throw ScannerException.NotInitialized()
            camera.stopCamera()
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun startDetector(callback: (Result<Unit>) -> Unit) {
        try {
            val camera = this.camera ?: throw ScannerException.NotInitialized()
            camera.startDetector()
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun stopDetector(callback: (Result<Unit>) -> Unit) {
        try {
            val camera = this.camera ?: throw ScannerException.NotInitialized()
            camera.stopDetector()
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun dispose(callback: (Result<Unit>) -> Unit) {
        try {
            camera?.also {
                it.stopCamera()
                it.flutterTextureEntry.release()
                activityBinding?.removeRequestPermissionsResultListener(it)
            }
            camera = null
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun toggleTorch(callback: (Result<Boolean>) -> Unit) {
        try {
            val camera = this.camera ?: throw ScannerException.NotInitialized()
            camera.toggleTorch()
                .addListener(
                    { callback(Result.success(camera.torchState)) },
                    ContextCompat.getMainExecutor(camera.activity)
                )
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun changeConfiguration(configuration: UpdateConfiguration, callback: (Result<PreviewConfiguration>) -> Unit) {
        try {
            val camera = this.camera ?: throw ScannerException.NotInitialized()
            // Use Pigeon configuration directly
            val result = camera.changeConfiguration(configuration)
            callback(Result.success(result))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun scanImage(imageSource: ImageSourceData, callback: (Result<ScanData>) -> Unit) {
        try {
            scanImageInternal(imageSource)
                .addOnSuccessListener { barcodes ->
                    val pigeonBarcodes = barcodes?.mapNotNull { it.toPigeonBarcode() } ?: emptyList()
                    val scanData = ScanData(
                        barcodes = if (pigeonBarcodes.isNotEmpty()) pigeonBarcodes else null,
                        ocrData = null  // scanImage currently only supports barcodes, not OCR
                    )
                    callback(Result.success(scanData))
                }
                .addOnFailureListener { callback(Result.failure(it)) }
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun retrieveCachedImage(code: String, callback: (Result<String?>) -> Unit) {
        try {
            val image = ImageHelper.getInstance().retrieveImagePath(code)
            callback(Result.success(image))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun clearCachedImage(callback: (Result<Unit>) -> Unit) {
        try {
            val context = pluginBinding?.applicationContext ?: throw ScannerException.ActivityNotConnected()
            ImageHelper.getInstance().clearCache(context)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    // Helper methods
    @SuppressLint("UnsafeOptInUsageError")
    private fun scanImageInternal(imageSource: ImageSourceData): Task<List<com.google.mlkit.vision.barcode.common.Barcode>?> {
        val options = BarcodeScannerOptions.Builder().setBarcodeFormats(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_ALL_FORMATS).build()
        val scanner = BarcodeScanning.getClient(options)

        return when {
            imageSource.imageBytes != null -> {
                // Binary image data
                scanner.process(
                    InputImage.fromBitmap(
                        BitmapFactory.decodeByteArray(
                            imageSource.imageBytes,
                            0,
                            imageSource.imageBytes.size
                        ),
                        imageSource.rotation?.toInt() ?: 0
                    )
                )
            }
            imageSource.useImagePicker -> {
                // Image picker
                if (pickImageCompleter?.task?.isComplete == false)
                    throw ScannerException.AlreadyPicking()

                val activityBinding = activityBinding ?: throw ScannerException.ActivityNotConnected()

                val intent = Intent(Intent.ACTION_PICK, android.provider.MediaStore.Images.Media.INTERNAL_CONTENT_URI)
                intent.type = "image/*"

                this.pickImageCompleter = TaskCompletionSource<Uri?>()
                activityBinding.activity.startActivityForResult(intent, 1)

                return pickImageCompleter!!.task.continueWithTask {
                    if (it.result == null) Tasks.forResult(null) else
                        scanner.process(
                            InputImage.fromFilePath(
                                activityBinding.activity,
                                it.result as Uri
                            )
                        )
                }
            }
            else -> {
                Tasks.forResult(null)
            }
        }
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
}
