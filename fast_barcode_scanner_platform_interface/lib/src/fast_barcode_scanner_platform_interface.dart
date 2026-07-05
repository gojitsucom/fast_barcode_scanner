import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pigeon_fast_barcode_scanner.dart';
import 'pigeon_barcode_scanner.dart';

/// Callback handler method for receiving scanned codes.
typedef OnDetectionHandler = void Function(List<BarcodeData>);

/// Callback handler method for receiving errors reported by the native side.
typedef OnErrorHandler = void Function(
  String errorCode,
  String errorMessage,
  String? errorDetails,
);

/// Error codes reported by the native side for camera session lifecycle
/// failures. Must stay in sync with the platform implementations.
abstract class ScannerErrorCodes {
  /// The capture session was interrupted (e.g. the camera device is in use
  /// by another session, or the app moved to a multitasking mode that
  /// revoked camera access). The preview is not delivering frames.
  static const sessionInterrupted = 'SESSION_INTERRUPTED';

  /// A previously reported interruption has ended and the session resumed.
  static const sessionInterruptionEnded = 'SESSION_INTERRUPTION_ENDED';

  /// The capture session did not enter the running state after start was
  /// requested, and no interruption was reported.
  static const sessionStartFailed = 'SESSION_START_FAILED';
}

/// The interface that implementations of fast_barcode_scanner must implement.
///
/// Platform implementations should extend this class rather than implement it as `fast_barcode_scanner`
/// Extending this class (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [FastBarcodeScannerPlatform] methods.
abstract class FastBarcodeScannerPlatform extends PlatformInterface {
  FastBarcodeScannerPlatform() : super(token: _token);

  static const Object _token = Object();

  static FastBarcodeScannerPlatform _instance =
      PigeonFastBarcodeScanner();

  /// The default instance of [FastBarcodeScannerPlatform] to use.
  ///
  /// Defaults to [PigeonFastBarcodeScanner].
  static FastBarcodeScannerPlatform get instance => _instance;

  /// Platform specific plugins should set this with their own platform-specific
  /// class that extends [FastBarcodeScannerPlatform] when they register themselves.
  static set instance(FastBarcodeScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initializes and starts the native camera interface.
  /// Returns a [PreviewConfiguration] the camera is setup with.
  Future<PreviewConfiguration> init(
      List<BarcodeType> types,
      Resolution resolution,
      Framerate framerate,
      DetectionMode detectionMode,
      CameraPosition position,
      {IOSApiMode? apiMode}) {
    throw UnimplementedError('init() has not been implemented');
  }

  /// Resumes the camera from the stopped state on the platform.
  Future<void> start() {
    throw UnimplementedError('resume() has not been implemented');
  }

  /// Stops the camera on the platform.
  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented');
  }

  // Starts the detector, if it was paused.
  Future<void> startDetector() {
    throw UnimplementedError('startDetector() has not been implemented');
  }

  // Stops the detector. Keeps the preview running.
  Future<void> stopDetector() {
    throw UnimplementedError('stopDetector() has not been implemented');
  }

  /// Stops and clears the camera resources.
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented');
  }

  /// Toggles the torch, if available.
  Future<bool> toggleTorch() {
    throw UnimplementedError('toggleTorch() has not been implemented');
  }

  /// Changes the supplied camera settings.
  /// Nil values are ignored and stay unchanged.
  Future<PreviewConfiguration> changeConfiguration({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) {
    throw UnimplementedError('changeConfiguration() has not been implemented');
  }

  /// Set the method to be called when a barcode is detected
  void setOnDetectHandler(OnDetectionHandler handler) {
    throw UnimplementedError('setOnDetectHandler() has not been implemented');
  }

  /// Set the method to be called when the native side reports an error,
  /// including camera session lifecycle failures (see [ScannerErrorCodes]).
  ///
  /// Pass null to stop receiving errors. Defaults to a no-op so existing
  /// platform implementations remain compatible.
  void setOnErrorHandler(OnErrorHandler? handler) {}

  Future<List<BarcodeData>?> scanImage(ImageSourceData source) {
    throw UnimplementedError('scanImage() has not been implemented');
  }

  Future<String?> retrieveCachedImage({required String code}) {
    throw UnimplementedError('retrieveCachedImage() has not been implemented');
  }

  Future<void> clearCachedImage() {
    throw UnimplementedError('clearCachedImage() has not been implemented');
  }
}
