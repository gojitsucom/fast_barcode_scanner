import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform extends FastBarcodeScannerPlatform {
  OnErrorHandler? errorHandler;
  OnDetectionHandler? detectHandler;
  int disposeCount = 0;
  int clearCachedImageCount = 0;

  @override
  Future<PreviewConfiguration> init(
    List<BarcodeType> types,
    Resolution resolution,
    Framerate framerate,
    DetectionMode detectionMode,
    CameraPosition position, {
    IOSApiMode? apiMode,
  }) async {
    return PreviewConfiguration(
      textureId: 0,
      targetRotation: 0,
      height: 1280,
      width: 720,
      analysisWidth: 720,
      analysisHeight: 1280,
    );
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    disposeCount++;
  }

  @override
  Future<void> clearCachedImage() async {
    clearCachedImageCount++;
  }

  @override
  void setOnDetectHandler(OnDetectionHandler handler) {
    detectHandler = handler;
  }

  @override
  void setOnErrorHandler(OnErrorHandler? handler) {
    errorHandler = handler;
  }
}

void main() {
  final fakePlatform = _FakePlatform();
  FastBarcodeScannerPlatform.instance = fakePlatform;
  final controller = CameraController();

  Future<void> initializeController() {
    return controller.initialize(
      types: const [BarcodeType.qr],
      resolution: Resolution.hd720,
      framerate: Framerate.fps30,
      position: CameraPosition.back,
      detectionMode: DetectionMode.continuous,
    );
  }

  setUp(() async {
    fakePlatform.errorHandler = null;
    await initializeController();
  });

  tearDown(() async {
    await controller.dispose();
  });

  group('session lifecycle events from the native side', () {
    test('initialize registers an error handler with the platform', () {
      expect(fakePlatform.errorHandler, isNotNull);
    });

    test('session interruption does not change the scanner state', () {
      // Backgrounding, Siri, calls and Split View all interrupt the session.
      // They end on their own, so they must not swap the preview for onError.
      fakePlatform.errorHandler!(
        ScannerErrorCodes.sessionInterrupted,
        'Camera session was interrupted',
        'videoDeviceInUseByAnotherClient',
      );

      expect(controller.events.value, ScannerEvent.resumed);
      expect(controller.state.hasError, isFalse);
    });

    test('session resume clears an earlier start failure', () {
      fakePlatform.errorHandler!(
        ScannerErrorCodes.sessionStartFailed,
        'Capture session did not start',
        null,
      );
      fakePlatform.errorHandler!(
        ScannerErrorCodes.sessionInterruptionEnded,
        'Camera session resumed',
        null,
      );

      expect(controller.events.value, ScannerEvent.resumed);
      expect(controller.state.hasError, isFalse);
    });

    test('session start failure surfaces as ScannerEvent.error', () {
      fakePlatform.errorHandler!(
        ScannerErrorCodes.sessionStartFailed,
        'Capture session did not start',
        null,
      );

      expect(controller.events.value, ScannerEvent.error);
      expect(controller.state.hasError, isTrue);
    });

    test('unrelated error codes do not change the scanner state', () {
      // Non-session errors (e.g. a failed still-image scan) are logged by the
      // platform layer but must not tear down a healthy live preview.
      fakePlatform.errorHandler!('SCAN_IMAGE_FAILED', 'could not decode', null);

      expect(controller.events.value, ScannerEvent.resumed);
      expect(controller.state.hasError, isFalse);
    });

    test('dispose unregisters the error handler', () async {
      await controller.dispose();

      expect(fakePlatform.errorHandler, isNull);

      // Re-initialize so tearDown's dispose acts on a live controller.
      await initializeController();
    });
  });

  group('clearCachedImage', () {
    // The driver app calls this after a background upload finishes, when a
    // different scanner screen may own the camera. Disposing there stopped
    // that camera while the Dart state still reported it initialized.
    test('clears the cache without disposing the camera', () async {
      fakePlatform.disposeCount = 0;
      fakePlatform.clearCachedImageCount = 0;

      await controller.clearCachedImage();

      expect(fakePlatform.clearCachedImageCount, 1);
      expect(fakePlatform.disposeCount, 0);
      expect(controller.state.isInitialized, isTrue);
    });
  });
}
