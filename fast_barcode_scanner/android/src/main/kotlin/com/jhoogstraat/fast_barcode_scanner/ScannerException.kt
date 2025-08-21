package com.jhoogstraat.fast_barcode_scanner

import com.jhoogstraat.fast_barcode_scanner.pigeon.Framerate
import com.jhoogstraat.fast_barcode_scanner.pigeon.Resolution
import com.jhoogstraat.fast_barcode_scanner.pigeon.ScannerConfiguration
import com.jhoogstraat.fast_barcode_scanner.pigeon.FlutterError
import java.io.IOException

fun Exception.asFlutterResult(callback: (Result<Unit>) -> Unit) {
    if (this is ScannerException) {
        callback(Result.failure(this.toFlutterError()))
    } else {
        callback(Result.failure(ScannerException.Unknown(this).toFlutterError()))
    }
}

sealed class ScannerException : Exception() {
    class NotInitialized : ScannerException()
    class AlreadyInitialized : ScannerException()
    class NotRunning : ScannerException()
    class AlreadyRunning : ScannerException()
    class NoInputDeviceForConfig(val configuration: ScannerConfiguration) : ScannerException()
    class Unauthorized : ScannerException()
    class ConfigurationException(val error: Exception) : ScannerException()
    class InvalidArguments(val args: HashMap<String, Any>) : ScannerException()
    class InvalidCodeType(val type: String) : ScannerException()
    class LoadingFailed(val error: IOException) : ScannerException()
    class AnalysisFailed(val error: Exception) : ScannerException()
    class AlreadyPicking() : ScannerException()
    class Unknown(val error: Exception) : ScannerException()
    class CameraNotSuitable(val resolution: Resolution, val framerate: Framerate) :
        ScannerException()

    /* Android specific */
    class ActivityNotConnected : ScannerException()

    fun toFlutterError(): FlutterError {
        return when (this) {
            is AlreadyInitialized -> FlutterError(
                "ALREADY_INITIALIZED",
                "Camera is already initialized",
                null
            )
            is NotInitialized -> FlutterError(
                "NOT_INITIALIZED",
                "Camera has not been initialized",
                null
            )
            is NotRunning -> FlutterError("NOT_RUNNING", "Camera is not running", null)
            is AlreadyRunning -> FlutterError("ALREADY_RUNNING", "Camera is already running", null)
            is CameraNotSuitable -> FlutterError(
                "CAMERA_NOT_SUITABLE",
                "The camera does not support the requested resolution and framerate combination",
                "$resolution $framerate"
            )
            is ConfigurationException -> FlutterError(
                "CONFIGURATION_FAILED",
                "The configuration could not be applied",
                error.localizedMessage
            )
            is NoInputDeviceForConfig -> FlutterError(
                "NO_INPUT_DEVICE",
                "No input device found for configuration. Are you using a simulator?",
                "$configuration"
            )
            is Unauthorized -> FlutterError(
                "UNAUTHORIZED",
                "The application is not authorized to use the camera device",
                null
            )
            is InvalidArguments -> FlutterError(
                "INVALID_ARGUMENT",
                "Invalid arguments provided",
                args
            )
            is InvalidCodeType -> FlutterError("INVALID_CODE", "Invalid code type", type)
            is ActivityNotConnected -> FlutterError("NO_ACTIVITY", "No activity is connected", null)
            is LoadingFailed -> FlutterError(
                "LOADING_FAILED",
                "Could not load asset",
                error.localizedMessage
            )
            is AnalysisFailed -> FlutterError(
                "ANALYSIS_FAILED",
                "Could not analyse asset",
                error.localizedMessage
            )
            is AlreadyPicking -> FlutterError(
                "ALREADY_PICKING",
                "Already picking an image to analyze",
                null
            )
            is Unknown -> FlutterError(
                "UNKNOWN",
                "Unknown error occurred",
                error.localizedMessage
            )
        }
    }
}