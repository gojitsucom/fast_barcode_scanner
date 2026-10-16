import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('setOnErrorHandler', () {
    test('onError forwards code, message and details to the handler', () {
      final scanner = PigeonFastBarcodeScanner();
      final received = <(String, String, String?)>[];

      scanner.setOnErrorHandler((code, message, details) {
        received.add((code, message, details));
      });

      scanner.onError(
        ScannerErrorCodes.sessionInterrupted,
        'video device in use by another client',
        'reason:1',
      );

      expect(received, [
        (
          ScannerErrorCodes.sessionInterrupted,
          'video device in use by another client',
          'reason:1',
        ),
      ]);
    });

    test('onError is a no-op after the handler is cleared', () {
      final scanner = PigeonFastBarcodeScanner();
      final received = <String>[];

      scanner.setOnErrorHandler((code, message, details) {
        received.add(code);
      });
      scanner.setOnErrorHandler(null);

      scanner.onError(ScannerErrorCodes.sessionStartFailed, 'boom', null);

      expect(received, isEmpty);
    });

    test('base platform ignores handlers without throwing', () {
      // Additive API: implementations that don't override it must not break.
      final platform = _MinimalPlatform();
      expect(() => platform.setOnErrorHandler((c, m, d) {}), returnsNormally);
    });
  });

  group('ScannerErrorCodes', () {
    test('exposes the session lifecycle codes used by the native side', () {
      expect(ScannerErrorCodes.sessionInterrupted, 'SESSION_INTERRUPTED');
      expect(
        ScannerErrorCodes.sessionInterruptionEnded,
        'SESSION_INTERRUPTION_ENDED',
      );
      expect(ScannerErrorCodes.sessionStartFailed, 'SESSION_START_FAILED');
    });
  });
}

class _MinimalPlatform extends FastBarcodeScannerPlatform {}
