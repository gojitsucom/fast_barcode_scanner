import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform extends FastBarcodeScannerPlatform {
  OnErrorHandler? errorHandler;
  OnDetectionHandler? detectHandler;

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
  Future<void> dispose() async {}

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
}
