package com.jhoogstraat.fast_barcode_scanner

import ImageHelper
import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.util.Log
import android.view.Surface
import androidx.annotation.OptIn
import androidx.camera.core.*
import androidx.camera.core.Camera
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.TaskCompletionSource
import com.google.common.util.concurrent.ListenableFuture
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.jhoogstraat.fast_barcode_scanner.pigeon.CameraPosition
import com.jhoogstraat.fast_barcode_scanner.pigeon.DetectionMode
import com.jhoogstraat.fast_barcode_scanner.pigeon.PreviewConfiguration
import com.jhoogstraat.fast_barcode_scanner.pigeon.ScannerConfiguration
import com.jhoogstraat.fast_barcode_scanner.pigeon.UpdateConfiguration
import com.jhoogstraat.fast_barcode_scanner.scanner.MLKitBarcodeScanner
import com.jhoogstraat.fast_barcode_scanner.scanner.OnDetectedListener
import com.jhoogstraat.fast_barcode_scanner.pigeon.*
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class Camera(
    val activity: Activity,
    val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry,
    configuration: ScannerConfiguration,
    private val listener: (List<Barcode>) -> Unit
) : RequestPermissionsResultListener {

    /* Scanner configuration */
    private var scannerConfiguration: ScannerConfiguration

    /* Camera */
    private lateinit var camera: Camera
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var cameraSelector: CameraSelector
    private var cameraExecutor: ExecutorService
    private lateinit var cameraSurfaceProvider: Preview.SurfaceProvider
    private lateinit var preview: Preview
    private lateinit var imageAnalysis: ImageAnalysis

    /* ML Kit */
    private var barcodeScanner: MLKitBarcodeScanner

    /* State */
    private var isInitialized = false
    private val isRunning: Boolean
        get() = cameraProvider.isBound(preview)
    val torchState: Boolean
        get() = camera.cameraInfo.torchState.value == TorchState.ON

    private var permissionsCompleter: TaskCompletionSource<Unit>? = null

    /* Companion */
    companion object {
        private const val TAG = "fast_barcode_scanner"
        private const val PERMISSIONS_REQUEST_CODE = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

    init {
        try {
            scannerConfiguration = configuration

            val options = BarcodeScannerOptions.Builder()
                .setBarcodeFormats(0, *scannerConfiguration.types.mapNotNull { it?.mlKitFormat }.toIntArray())
                .build()

            barcodeScanner = MLKitBarcodeScanner(options, object : OnDetectedListener<List<Barcode>> {
                @OptIn(ExperimentalGetImage::class)
                override fun onSuccess(codes: List<Barcode>, imageProxy: ImageProxy) {
                    CoroutineScope(Dispatchers.Main).launch {
                        if (codes.isNotEmpty()) {
                            if (scannerConfiguration.mode == DetectionMode.PAUSE_DETECTION) {
                                stopDetector()
                            } else if (scannerConfiguration.mode == DetectionMode.PAUSE_VIDEO) {
                                stopCamera()
                            }
                            val code = codes.first().displayValue
                            if (code != null) {
                                ImageHelper.getInstance()
                                    .storeImageToCache(
                                        imageProxy.image!!,
                                        code,
                                        activity.applicationContext
                                    )
                                listener(codes)
                            }
                        }
                        imageProxy.close()
                    }
                }
            }) {
                Log.e(TAG, "Error in MLKit", it)
            }

            // Create Camera Thread
            cameraExecutor = Executors.newSingleThreadExecutor()

        } catch (e: Exception) {
            throw ScannerException.InvalidArguments(configuration.toMap())
        }
    }

    fun requestPermissions(): Task<Unit> {
        permissionsCompleter = TaskCompletionSource<Unit>()

        if (ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_DENIED
        ) {
            ActivityCompat.requestPermissions(
                activity,
                REQUIRED_PERMISSIONS,
                PERMISSIONS_REQUEST_CODE
            )
        } else {
            permissionsCompleter!!.setResult(null)
        }

        return permissionsCompleter!!.task
    }

    /**
     * Fetching the camera is an async task.
     * Separating it into a dedicated method
     * allows to load the camera at any time.
     */
    fun loadCamera(): Task<PreviewConfiguration> {
        if (ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_DENIED
        ) {
            throw ScannerException.Unauthorized()
        }

        // ProcessCameraProvider.configureInstance(Camera2Config.defaultConfig())
        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)

        val loadingCompleter = TaskCompletionSource<PreviewConfiguration>()
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            isInitialized = true
            bindCameraUseCases()
            loadingCompleter.setResult(getPreviewConfiguration())
        }, ContextCompat.getMainExecutor(activity))

        return loadingCompleter.task
    }

    private fun buildSelectorAndUseCases() {
        cameraSelector = CameraSelector.Builder()
            .requireLensFacing(
                if (scannerConfiguration.position == CameraPosition.BACK)
                    CameraSelector.LENS_FACING_BACK
                else
                    CameraSelector.LENS_FACING_FRONT
            )
            .build()

        // TODO: Handle rotation properly
        preview = Preview.Builder()
            .setTargetRotation(Surface.ROTATION_0)
            .setTargetResolution(android.util.Size(scannerConfiguration.resolution.width, scannerConfiguration.resolution.height))
            .build()

        imageAnalysis = ImageAnalysis.Builder()
            .setTargetRotation(Surface.ROTATION_0)
            .setTargetResolution(android.util.Size(scannerConfiguration.resolution.width, scannerConfiguration.resolution.height))
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { it.setAnalyzer(cameraExecutor, barcodeScanner) }
    }

    private fun bindCameraUseCases() {
        Log.d(TAG, "Requested Resolution: ${scannerConfiguration.resolution.portrait()}")

        // Selector and UseCases need to be rebuild when rebinding them
        buildSelectorAndUseCases()

        // As required by CameraX, unbinds all use cases before trying to re-bind any of them.
        cameraProvider.unbindAll()

        // Bind camera to Lifecycle
        camera = cameraProvider.bindToLifecycle(
            activity as LifecycleOwner,
            cameraSelector,
            preview,
            imageAnalysis
        )

        // Setup Surface
        cameraSurfaceProvider = Preview.SurfaceProvider {
            val surfaceTexture = flutterTextureEntry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(it.resolution.width, it.resolution.height)
            it.provideSurface(Surface(surfaceTexture), cameraExecutor, {})
        }

        // Attach the viewfinder's surface provider to preview use case
        preview.setSurfaceProvider(cameraExecutor, cameraSurfaceProvider)
    }

    fun startCamera() {
        if (!isInitialized)
            throw ScannerException.NotInitialized()
        else if (isRunning)
            return

        bindCameraUseCases()
    }

    fun stopCamera() {
        if (!isRunning || !isInitialized) {
            return
        }

        cameraProvider.unbindAll()
    }

    fun startDetector() {
        if (!isInitialized)
            throw ScannerException.NotInitialized()
        else if (!isRunning)
            throw ScannerException.NotRunning()
        else if (!cameraProvider.isBound(imageAnalysis))
            throw ScannerException.NotInitialized()

        imageAnalysis.setAnalyzer(cameraExecutor, barcodeScanner)
    }

    fun stopDetector() {
        if (!isInitialized)
            throw ScannerException.NotInitialized()
        else if (!isRunning)
            throw ScannerException.NotRunning()
        else if (!cameraProvider.isBound(imageAnalysis))
            throw ScannerException.NotInitialized()

        imageAnalysis.clearAnalyzer()
    }

    fun toggleTorch(): ListenableFuture<Void> {
        if (!isInitialized)
            throw ScannerException.NotInitialized()
        else if (!isRunning)
            throw ScannerException.NotRunning()

        return camera.cameraControl.enableTorch(!torchState)
    }

    fun changeConfiguration(updateConfig: UpdateConfiguration): PreviewConfiguration {
        if (!isInitialized)
            throw ScannerException.NotInitialized()

        try {
            scannerConfiguration = scannerConfiguration.copy(
                types = updateConfig.types ?: scannerConfiguration.types,
                mode = updateConfig.mode ?: scannerConfiguration.mode,
                resolution = updateConfig.resolution ?: scannerConfiguration.resolution,
                framerate = updateConfig.framerate ?: scannerConfiguration.framerate,
                position = updateConfig.position ?: scannerConfiguration.position
            )
        } catch (e: Exception) {
            throw ScannerException.InvalidArguments(updateConfig.toMap())
        }

        bindCameraUseCases()
        return getPreviewConfiguration()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            permissionsCompleter?.also { completer ->
                if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    completer.setResult(null)
                } else {
                    completer.setException(ScannerException.Unauthorized())
                }
            }
        }

        return true
    }

    private fun getPreviewConfiguration(): PreviewConfiguration {
        val previewRes =
            preview.resolutionInfo?.resolution ?: throw ScannerException.NotInitialized()
        val analysisRes =
            imageAnalysis.resolutionInfo?.resolution ?: throw ScannerException.NotInitialized()

        return PreviewConfiguration(
            flutterTextureEntry.id(),
            0,
            height = previewRes.height.toLong(),
            width = previewRes.width.toLong(),
            analysisWidth = analysisRes.width.toLong(),
            analysisHeight = analysisRes.height.toLong()
        )
    }


}