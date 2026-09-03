import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails the first toggle the way a camera that is not ready does, then works.
class _FlakyTorchPlatform extends FastBarcodeScannerPlatform {
  int toggleCalls = 0;

  @override
  Future<bool> toggleTorch() async {
    toggleCalls++;
    if (toggleCalls == 1) throw StateError('camera not ready');
    return true;
  }
}

void main() {
  test(
    'a failed torch toggle does not disable the torch for the rest of the '
    'process: the next toggle reaches the platform again',
    () async {
      final platform = _FlakyTorchPlatform();
      // The controller is a lazy singleton that captures the platform at its
      // first construction, so the fake must be installed before the first
      // CameraController() in this file — keep it that way in any new test.
      FastBarcodeScannerPlatform.instance = platform;
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
      // Same singleton and fake as above: this file's first test already
      // consumed the throwing call, so start the sequence again.
      final platform =
          FastBarcodeScannerPlatform.instance as _FlakyTorchPlatform;
      platform.toggleCalls = 0;

      await expectLater(controller.toggleTorch(), throwsA(isA<StateError>()));
      expect(controller.events.value, ScannerEvent.error);
      expect(controller.state.hasError, isTrue);

      await controller.toggleTorch();

      expect(controller.events.value, ScannerEvent.resumed);
      expect(controller.state.hasError, isFalse);
    },
  );
}
