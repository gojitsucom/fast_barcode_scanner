package com.jhoogstraat.fast_barcode_scanner

import ImageHelper
import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.Image
import android.util.Log
import android.view.Surface
import androidx.annotation.OptIn
import androidx.camera.core.*
import androidx.camera.core.Camera as CameraX
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.TaskCompletionSource
import com.google.common.util.concurrent.ListenableFuture
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
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
    private val configuration: ScannerConfiguration,
    private val listener: (List<Barcode>) -> Unit
) : RequestPermissionsResultListener {

    /* Scanner configuration */
    private var scannerConfiguration: ScannerConfiguration = configuration

    /* Camera */
    private lateinit var camera: CameraX
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var cameraSelector: CameraSelector
    private var cameraExecutor: ExecutorService
    private lateinit var cameraSurfaceProvider: Preview.SurfaceProvider
    private lateinit var preview: Preview
    private lateinit var imageAnalysis: ImageAnalysis

    /* Scanner */
    private lateinit var barcodeScanner: MLKitBarcodeScanner

    /* State */
    private var isInitialized = false
    private var isStarted = false
    private var isDetecting = false

    /* Permissions */
    private var permissionsCompleter: TaskCompletionSource<Unit>? = null

    /* Torch */
    val torchState: Boolean
        get() = camera.cameraInfo.torchState.value == TorchState.ON

    companion object {
        private const val PERMISSIONS_REQUEST_CODE = 1
    }

    init {
        cameraExecutor = Executors.newSingleThreadExecutor()
        
        // Build barcode scanner options from configuration
        val formats = scannerConfiguration.types.mapNotNull { it?.mlKitFormat }.toIntArray()
        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(formats.firstOrNull() ?: Barcode.FORMAT_ALL_FORMATS, *formats.drop(1).toIntArray())
            .build()

        barcodeScanner = MLKitBarcodeScanner(options, object : OnDetectedListener {
            override fun onDetected(barcodes: List<Barcode>) {
                if (isDetecting) {
                    // Save images if needed
                    CoroutineScope(Dispatchers.IO).launch {
                        barcodes.forEach { barcode ->
                            barcode.rawValue?.let { code ->
                                ImageHelper.getInstance().saveImage(activity, code)
                            }
                        }
                    }
                    listener(barcodes)
                }
            }
        })
    }

    /**
     * Request camera permissions
     */
    fun requestPermissions(): Task<Unit> {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            return com.google.android.gms.tasks.Tasks.forResult(Unit)
        }

        if (permissionsCompleter?.task?.isComplete == false) {
            return permissionsCompleter!!.task
        }

        permissionsCompleter = TaskCompletionSource<Unit>()
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.CAMERA),
            PERMISSIONS_REQUEST_CODE
        )

        return permissionsCompleter!!.task
    }

    /**
     * Load camera and return preview configuration
     */
    fun loadCamera(): Task<PreviewConfiguration> {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_DENIED) {
            throw ScannerException.PermissionDenied
        }

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
        // Camera selector
        cameraSelector = CameraSelector.Builder()
            .requireLensFacing(
                if (scannerConfiguration.position == CameraPositionEnum.BACK)
                    CameraSelector.LENS_FACING_BACK
                else
                    CameraSelector.LENS_FACING_FRONT
            )
            .build()

        // Surface provider for Flutter texture
        cameraSurfaceProvider = Preview.SurfaceProvider { request ->
            val texture = flutterTextureEntry.surfaceTexture()
            texture.setDefaultBufferSize(request.resolution.width, request.resolution.height)
            val surface = Surface(texture)
            request.provideSurface(surface, cameraExecutor) { }
        }

        // Preview use case
        preview = Preview.Builder()
            .setTargetResolution(scannerConfiguration.resolution.toSize())
            .build()
        preview.setSurfaceProvider(cameraExecutor, cameraSurfaceProvider)

        // Image analysis use case
        imageAnalysis = ImageAnalysis.Builder()
            .setTargetResolution(scannerConfiguration.resolution.toSize())
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
        imageAnalysis.setAnalyzer(cameraExecutor, barcodeScanner)
    }

    private fun bindCameraUseCases() {
        if (!isInitialized) return

        buildSelectorAndUseCases()
        cameraProvider.unbindAll()

        try {
            camera = cameraProvider.bindToLifecycle(
                activity as LifecycleOwner,
                cameraSelector,
                preview,
                imageAnalysis
            )
        } catch (e: Exception) {
            Log.e("Camera", "Use case binding failed", e)
            throw ScannerException.CameraNotAvailable
        }
    }

    fun startCamera() {
        if (!isInitialized) throw ScannerException.NotInitialized()
        isStarted = true
    }

    fun stopCamera() {
        if (!isInitialized) throw ScannerException.NotInitialized()
        isStarted = false
    }

    fun startDetector() {
        if (!isInitialized) throw ScannerException.NotInitialized()
        isDetecting = true
    }

    fun stopDetector() {
        if (!isInitialized) throw ScannerException.NotInitialized()
        isDetecting = false
    }

    fun toggleTorch(): Task<Boolean> {
        if (!isInitialized) throw ScannerException.NotInitialized()
        return camera.cameraControl.enableTorch(!torchState)
    }

    fun changeConfiguration(newConfiguration: UpdateConfiguration): PreviewConfiguration {
        if (!isInitialized) throw ScannerException.NotInitialized()

        // Update scanner configuration with new values
        scannerConfiguration = ScannerConfiguration(
            types = newConfiguration.types ?: scannerConfiguration.types,
            mode = newConfiguration.mode ?: scannerConfiguration.mode,
            resolution = newConfiguration.resolution ?: scannerConfiguration.resolution,
            framerate = newConfiguration.framerate ?: scannerConfiguration.framerate,
            position = newConfiguration.position ?: scannerConfiguration.position,
            apiMode = scannerConfiguration.apiMode,
            confidence = scannerConfiguration.confidence
        )

        // Rebuild camera with new configuration
        bindCameraUseCases()
        return getPreviewConfiguration()
    }

    private fun getPreviewConfiguration(): PreviewConfiguration {
        val previewRes = preview.resolutionInfo?.resolution ?: throw ScannerException.NotInitialized()
        val analysisRes = imageAnalysis.resolutionInfo?.resolution ?: throw ScannerException.NotInitialized()

        return PreviewConfiguration(
            textureId = flutterTextureEntry.id(),
            targetRotation = 0,
            height = previewRes.height.toLong(),
            width = previewRes.width.toLong(),
            analysisWidth = analysisRes.width.toLong(),
            analysisHeight = analysisRes.height.toLong()
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            permissionsCompleter?.also { completer ->
                if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    completer.setResult(Unit)
                } else {
                    completer.setException(ScannerException.PermissionDenied)
                }
                permissionsCompleter = null
            }
        }
        return true
    }
}

// Extension to convert Resolution to Size
private fun ResolutionEnum.toSize(): android.util.Size {
    return android.util.Size(this.width, this.height)
}
