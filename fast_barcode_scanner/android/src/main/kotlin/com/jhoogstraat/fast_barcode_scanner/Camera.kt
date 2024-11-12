package com.jhoogstraat.fast_barcode_scanner

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import android.util.Base64
import android.util.Log
import android.view.Surface
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
import com.jhoogstraat.fast_barcode_scanner.scanner.MLKitBarcodeScanner
import com.jhoogstraat.fast_barcode_scanner.scanner.OnDetectedListener
import com.jhoogstraat.fast_barcode_scanner.types.*
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry
import java.io.ByteArrayOutputStream
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class Camera(
    val activity: Activity,
    val flutterTextureEntry: TextureRegistry.SurfaceTextureEntry,
    args: HashMap<String, Any>,
    private val listener: (List<Barcode>, String?) -> Unit
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
        val types = (args["types"] as ArrayList<String>)

        try {
            scannerConfiguration = ScannerConfiguration(
                types.mapNotNull { barcodeFormatMap[it] }
                    .toIntArray(),
                DetectionMode.valueOf(args["mode"] as String),
                Resolution.valueOf(args["res"] as String),
                Framerate.valueOf(args["fps"] as String),
                CameraPosition.valueOf(args["pos"] as String)
            )

            // Report to the user if any types are not supported
            if (types.count() != scannerConfiguration.formats.count()) {
                val unsupportedTypes = types.filter { !barcodeFormatMap.containsKey(it) }
                Log.d(TAG, "WARNING: Unsupported barcode types selected: $unsupportedTypes")
            }

        } catch (e: Exception) {
            throw ScannerException.InvalidArguments(args)
        }

        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(0, *scannerConfiguration.formats)
            .build()

        barcodeScanner = MLKitBarcodeScanner(options, object : OnDetectedListener<List<Barcode>> {
            override fun onSuccess(codes: List<Barcode>, image: Image) {
                if (codes.isNotEmpty()) {
                    if (scannerConfiguration.mode == DetectionMode.pauseDetection) {
                        stopDetector()
                    } else if (scannerConfiguration.mode == DetectionMode.pauseVideo) {
                        stopCamera()
                    }
                    val base64Image =
                        imageToBase64(image, Bitmap.CompressFormat.JPEG);
                    listener(codes, base64Image)
                }
            }
        }) {
            Log.e(TAG, "Error in MLKit", it)
        }

        // Create Camera Thread
        cameraExecutor = Executors.newSingleThreadExecutor()
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
                if (scannerConfiguration.position == CameraPosition.back)
                    CameraSelector.LENS_FACING_BACK
                else
                    CameraSelector.LENS_FACING_FRONT
            )
            .build()

        // TODO: Handle rotation properly
        preview = Preview.Builder()
            .setTargetRotation(Surface.ROTATION_0)
            .setTargetResolution(scannerConfiguration.resolution.portrait())
            .build()

        imageAnalysis = ImageAnalysis.Builder()
            .setTargetRotation(Surface.ROTATION_0)
            .setTargetResolution(scannerConfiguration.resolution.portrait())
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
        if (!isInitialized) {
            throw ScannerException.NotInitialized()
        } else if (!isRunning) {
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

    fun changeConfiguration(args: HashMap<String, Any>): PreviewConfiguration {
        if (!isInitialized)
            throw ScannerException.NotInitialized()

        try {
            val formats = if (args.containsKey("types")) (args["types"] as ArrayList<String>).map {
                barcodeFormatMap[it] ?: throw ScannerException.InvalidCodeType(it)
            }.toIntArray() else scannerConfiguration.formats
            val detectionMode =
                if (args.containsKey("mode")) DetectionMode.valueOf(args["mode"] as String) else scannerConfiguration.mode
            val resolution =
                if (args.containsKey("res")) Resolution.valueOf(args["res"] as String) else scannerConfiguration.resolution
            val framerate =
                if (args.containsKey("fps")) Framerate.valueOf(args["fps"] as String) else scannerConfiguration.framerate
            val position =
                if (args.containsKey("pos")) CameraPosition.valueOf(args["pos"] as String) else scannerConfiguration.position

            scannerConfiguration = scannerConfiguration.copy(
                formats = formats,
                mode = detectionMode,
                resolution = resolution,
                framerate = framerate,
                position = position
            )
        } catch (e: ScannerException) {
            throw e
        } catch (e: Exception) {
            throw ScannerException.InvalidArguments(args)
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
            previewRes.height,
            previewRes.width,
            analysisWidth = analysisRes.width,
            analysisHeight = analysisRes.height
        )
    }


    fun imageToBase64(
        image: Image,
        format: Bitmap.CompressFormat = Bitmap.CompressFormat.PNG
    ): String {
        val bitmap = imageToBitmap(image)
        val outputStream = ByteArrayOutputStream()

        // Compress the bitmap with the specified format (e.g., PNG or JPEG)
        bitmap.compress(format, 100, outputStream)

        // Get the byte array from the output stream
        val byteArray = outputStream.toByteArray()

        // Encode the byte array to Base64 string
        return Base64.encodeToString(byteArray, Base64.DEFAULT)
    }

    private fun imageToBitmap(image: Image): Bitmap {
        if (image.format == ImageFormat.YUV_420_888) {
            val yBuffer = image.planes[0].buffer // Y
            val uBuffer = image.planes[1].buffer // U
            val vBuffer = image.planes[2].buffer // V

            val ySize = yBuffer.remaining()
            val uSize = uBuffer.remaining()
            val vSize = vBuffer.remaining()

            val nv21 = ByteArray(ySize + uSize + vSize)

            // Copy Y channel
            yBuffer[nv21, 0, ySize]

            // Copy VU channel (assuming NV21 format)
            vBuffer[nv21, ySize, vSize]
            uBuffer[nv21, ySize + vSize, uSize]

            val yuvImage = YuvImage(nv21, ImageFormat.NV21, image.width, image.height, null)
            val out = ByteArrayOutputStream()
            yuvImage.compressToJpeg(Rect(0, 0, image.width, image.height), 100, out)
            val jpegBytes = out.toByteArray()

            return BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
        } else {
            throw IllegalArgumentException("Unsupported image format")
        }
    }
}