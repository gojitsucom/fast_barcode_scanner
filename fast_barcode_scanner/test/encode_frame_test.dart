import 'dart:io';

import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform extends FastBarcodeScannerPlatform {
  String? reportedPath;
  int? askedFor;
  Object? failure;

  @override
  Future<String?> encodeFrame({required int frameId}) async {
    askedFor = frameId;
    final failure = this.failure;
    if (failure != null) throw failure;
    return reportedPath;
  }
}

void main() {
  final fakePlatform = _FakePlatform();
  FastBarcodeScannerPlatform.instance = fakePlatform;
  final controller = CameraController();

  setUp(() {
    fakePlatform.reportedPath = null;
    fakePlatform.askedFor = null;
    fakePlatform.failure = null;
  });

  group('encodeFrame', () {
    test('asks the platform for the frame id', () async {
      await controller.encodeFrame(42);
      expect(fakePlatform.askedFor, 42);
    });

    test('returns null when the frame is gone', () async {
      expect(await controller.encodeFrame(42), isNull);
    });

    test('resolves a file URL to its path', () async {
      fakePlatform.reportedPath = 'file:///var/mobile/frames/f%7C1.jpeg';
      expect(
        await controller.encodeFrame(1),
        '/var/mobile/frames/f|1.jpeg',
      );
    }, skip: Platform.isWindows);

    test('platform throw is rethrown and leaves events untouched', () async {
      final failure = StateError('encode failed');
      fakePlatform.failure = failure;
      controller.events.value = ScannerEvent.resumed;

      await expectLater(controller.encodeFrame(1), throwsA(same(failure)));

      expect(controller.events.value, ScannerEvent.resumed);
      expect(controller.state.hasError, isFalse);
    });
  });
}
