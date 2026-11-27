import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform extends FastBarcodeScannerPlatform {
  bool? legacyImageCache;
  bool? frameRing;

  @override
  Future<PreviewConfiguration> init(
    List<BarcodeType> types,
    Resolution resolution,
    Framerate framerate,
    DetectionMode detectionMode,
    CameraPosition position, {
    IOSApiMode? apiMode,
    bool? legacyImageCache,
    bool? frameRing,
  }) async {
    this.legacyImageCache = legacyImageCache;
    this.frameRing = frameRing;
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
  Future<void> dispose() async {}

  @override
  void setOnDetectHandler(OnDetectionHandler handler) {}

  @override
  void setOnErrorHandler(OnErrorHandler? handler) {}
}

void main() {
  final fakePlatform = _FakePlatform();
  FastBarcodeScannerPlatform.instance = fakePlatform;
  final controller = CameraController();

  tearDown(() => controller.dispose());

  group('initialize', () {
    test('defaults to legacy image cache on and frame ring off', () async {
      await controller.initialize(
        types: const [BarcodeType.qr],
        resolution: Resolution.hd720,
        framerate: Framerate.fps30,
        position: CameraPosition.back,
        detectionMode: DetectionMode.continuous,
      );

      expect(fakePlatform.legacyImageCache, isTrue);
      expect(fakePlatform.frameRing, isFalse);
      expect(controller.state.scannerConfig?.frameRing, isFalse);
    });

    test('forwards frameRing and legacyImageCache to the platform', () async {
      await controller.initialize(
        types: const [BarcodeType.qr],
        resolution: Resolution.hd720,
        framerate: Framerate.fps30,
        position: CameraPosition.back,
        detectionMode: DetectionMode.continuous,
        legacyImageCache: false,
        frameRing: true,
      );

      expect(fakePlatform.legacyImageCache, isFalse);
      expect(fakePlatform.frameRing, isTrue);
      expect(controller.state.scannerConfig?.frameRing, isTrue);
    });
  });
}
