package com.jhoogstraat.fast_barcode_scanner

import ApiModeConfig
import BarcodeData
import BarcodeDetectionHandler
import BarcodeType
import CameraPosition
import DetectionMode
import Framerate
import Point
import PreviewConfiguration
import Resolution
import ScannerPlatformInterface
import android.app.Activity
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.common.Barcode
import com.jhoogstraat.fast_barcode_scanner.types.ScannerException
import com.jhoogstraat.fast_barcode_scanner.types.barcodeStringMap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

class FastBarcodeScannerPlugin : FlutterPlugin, ActivityAware, ScannerPlatformInterface {
    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var camera: Camera? = null
    private var barcodeHandler: BarcodeDetectionHandler? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        pluginBinding = flutterPluginBinding
        ScannerPlatformInterface.setUp(flutterPluginBinding.binaryMessenger, this)
        barcodeHandler = BarcodeDetectionHandler(flutterPluginBinding.binaryMessenger)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        pluginBinding = null
        ScannerPlatformInterface.setUp(binding.binaryMessenger, null)
        barcodeHandler = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        dispose(
            callback = {}
        )
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    // Implement ScannerPlatformInterface methods
    override fun initialize(
        types: List<BarcodeType>,
        resolution: Resolution,
        framerate: Framerate,
        detectionMode: DetectionMode,
        position: CameraPosition,
        apiMode: ApiModeConfig?,
        callback: (Result<PreviewConfiguration>) -> Unit
    ) {
        try {
            if (camera != null) {
                camera!!.requestPermissions()
                    .continueWithTask { camera!!.loadCamera() }
                    .addOnSuccessListener { callback(Result.success(it)) }
                    .addOnFailureListener { callback(Result.failure(it)) }
                return
            }

            this.pluginBinding ?: throw ScannerException.ActivityNotConnected()
            val activityBinding =
                this.activityBinding ?: throw ScannerException.ActivityNotConnected()

            val config = hashMapOf<String, Any>(
                "types" to types,
                "resolution" to resolution,
                "framerate" to framerate,
                "detectionMode" to detectionMode,
                "position" to position
            )

            val camera = Camera(
                activityBinding.activity,
                pluginBinding!!.textureRegistry.createSurfaceTexture(),
                config
            ) { barcodes ->
                barcodeHandler?.onBarcodeDetected(encodeBarcodes(barcodes)) { }
            }

            this.camera = camera
            activityBinding.addRequestPermissionsResultListener(camera)

            camera.requestPermissions()
                .continueWithTask { camera.loadCamera() }
                .addOnSuccessListener { callback(Result.success(it)) }
                .addOnFailureListener { callback(Result.failure(it)) }

        } catch (e: Exception) {
            e.printStackTrace()
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

    override fun updateConfiguration(
        types: List<BarcodeType>?,
        resolution: Resolution?,
        framerate: Framerate?,
        detectionMode: DetectionMode?,
        position: CameraPosition?,
        callback: (Result<PreviewConfiguration>) -> Unit
    ) {
        try {
            val camera = this.camera ?: throw ScannerException.NotInitialized()
            val config = hashMapOf<String, Any>()

            types?.let { config["types"] = it }
            resolution?.let { config["resolution"] = it }
            framerate?.let { config["framerate"] = it }
            detectionMode?.let { config["detectionMode"] = it }
            position?.let { config["position"] = it }

            val result = camera.changeConfiguration(config)
            callback(Result.success(result))
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

    override fun retrieveCachedImage(code: String, callback: (Result<String?>) -> Unit) {
        try {
            val camera = this.camera ?: throw ScannerException.NotInitialized()
            val image = ImageHelper.getInstance().retrieveImagePath(code)
            callback(Result.success(image))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun clearCachedImage(callback: (Result<Unit>) -> Unit) {
        try {
            val camera = this.camera ?: throw ScannerException.NotInitialized()
            if (camera.activity.applicationContext != null) {
                ImageHelper.getInstance().clearCache(camera.activity.applicationContext!!)
            }
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    private fun encodeBarcodes(barcodes: List<Barcode>): List<BarcodeData> {
        return barcodes.map {
            BarcodeData(
                barcodeStringMap[it.format] ?: "",
                it.rawValue ?: "",
                BarcodeValueType.ofRaw(it.valueType),
                it.cornerPoints?.map { point -> Point(point.x.toDouble(), point.y.toDouble()) }
            )
        }

    }
}