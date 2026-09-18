import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails the first toggle the way a camera that is not ready does, then works.
class _FlakyTorchPlatform extends FastBarcodeScannerPlatform {
  int toggleCalls = 0;
  bool failStartDetector = false;

  @override
  Future<bool> toggleTorch() async {
    toggleCalls++;
    if (toggleCalls == 1) throw StateError('camera not ready');
    return true;
  }

  @override
  Future<void> startDetector() async {
    if (failStartDetector) throw StateError('detector failed');
  }
}

void main() {
  // Reading `FastBarcodeScannerPlatform.instance` constructs the pigeon
  // platform, which registers a message channel and needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FlakyTorchPlatform platform;

  // The controller is a lazy singleton that captures the platform at its first
  // construction, so the fake is installed once, before any test constructs
  // it, and every test starts the fail-then-succeed sequence over.
  late FastBarcodeScannerPlatform originalPlatform;
  setUpAll(() {
    originalPlatform = FastBarcodeScannerPlatform.instance;
    platform = _FlakyTorchPlatform();
    FastBarcodeScannerPlatform.instance = platform;
  });
  // Restore the global so other suites in the same process see the real one.
  tearDownAll(() => FastBarcodeScannerPlatform.instance = originalPlatform);

  setUp(() => platform.toggleCalls = 0);

  test(
    'a failed torch toggle does not disable the torch for the rest of the '
    'process: the next toggle reaches the platform again',
    () async {
      final controller = CameraController();

      await expectLater(controller.toggleTorch(), throwsA(isA<StateError>()));
      expect(platform.toggleCalls, 1);

      final torchOn = await controller.toggleTorch();

      expect(platform.toggleCalls, 2,
          reason: 'the in-flight guard must be released after a throw');
      expect(torchOn, isTrue);
    },
  );

  test(
    'a successful retry takes the scanner back out of the error state the '
    'failed toggle put it in, so the preview returns while the torch is on',
    () async {
      final controller = CameraController();

      await expectLater(controller.toggleTorch(), throwsA(isA<StateError>()));
      expect(controller.events.value, ScannerEvent.error);
      expect(controller.state.hasError, isTrue);

      await controller.toggleTorch();

      expect(controller.events.value, ScannerEvent.resumed);
      expect(controller.state.hasError, isFalse);
    },
  );

  test(
    'a successful toggle leaves an error raised by another operation alone: '
    'a stopped detector must keep the error view up',
    () async {
      final controller = CameraController();
      // Burn the fake's one failing toggle so the toggles below succeed.
      await expectLater(controller.toggleTorch(), throwsA(isA<StateError>()));
      await controller.toggleTorch();

      platform.failStartDetector = true;
      await expectLater(controller.resumeScanner(), throwsA(isA<StateError>()));
      expect(controller.events.value, ScannerEvent.error);
      final detectorError = controller.state.error;

      await controller.toggleTorch();

      expect(controller.events.value, ScannerEvent.error,
          reason: 'the torch did not raise this error and may not clear it');
      expect(controller.state.error, same(detectorError));
      platform.failStartDetector = false;
    },
  );
}
