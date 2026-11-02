import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform extends FastBarcodeScannerPlatform {
  String? reportedPath;
  String? askedFor;

  @override
  Future<String?> retrieveCachedImage({required String code}) async {
    askedFor = code;
    return reportedPath;
  }
}

void main() {
  final fakePlatform = _FakePlatform();
  FastBarcodeScannerPlatform.instance = fakePlatform;
  final controller = CameraController();

  const iosDirectory =
      '/var/mobile/Containers/Data/Application/9814FB14/Documents/barcode_images';

  setUp(() {
    fakePlatform.reportedPath = null;
    fakePlatform.askedFor = null;
  });

  group('retrieveCachedImage', () {
    test('asks the platform for the code as given', () async {
      await controller.retrieveCachedImage('OSM0000000B40Z1N6|85140');
      expect(fakePlatform.askedFor, 'OSM0000000B40Z1N6|85140');
    });

    test('returns null when nothing is cached', () async {
      expect(await controller.retrieveCachedImage('x'), isNull);
    });

    test('returns a plain path as it is', () async {
      fakePlatform.reportedPath = '$iosDirectory/0b5d41cc9dc6bb2f.jpeg';
      expect(
        await controller.retrieveCachedImage('x'),
        '$iosDirectory/0b5d41cc9dc6bb2f.jpeg',
      );
    });

    test('resolves a file URL to its decoded path', () async {
      fakePlatform.reportedPath =
          'file://$iosDirectory/OSM0000000B40Z1N6%7C85140.jpeg';
      expect(
        await controller.retrieveCachedImage('x'),
        '$iosDirectory/OSM0000000B40Z1N6|85140.jpeg',
      );
    });

    test('returns a file URL it cannot resolve as it is', () async {
      fakePlatform.reportedPath = 'file://host/frame.jpeg';
      expect(
        await controller.retrieveCachedImage('x'),
        'file://host/frame.jpeg',
      );
    });
  });
}
