import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fast_barcode_scanner_platform_interface/src/pigeon_barcode_scanner.dart';
import 'package:fast_barcode_scanner_platform_interface/src/pigeon_fast_barcode_scanner.dart';

class TestPigeonFastBarcodeScanner extends PigeonFastBarcodeScanner {
  final List<ErrorCallback> errorCallbacks = [];

  @override
  void onError(String errorCode, String errorMessage, String? errorDetails) {
    errorCallbacks.add(ErrorCallback(errorCode, errorMessage, errorDetails));
    // Still call the parent implementation for debug printing
    super.onError(errorCode, errorMessage, errorDetails);
  }
}

class ErrorCallback {
  final String errorCode;
  final String errorMessage;
  final String? errorDetails;

  ErrorCallback(this.errorCode, this.errorMessage, this.errorDetails);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorCallback &&
        other.errorCode == errorCode &&
        other.errorMessage == errorMessage &&
        other.errorDetails == errorDetails;
  }

  @override
  int get hashCode => Object.hash(errorCode, errorMessage, errorDetails);

  @override
  String toString() =>
      'ErrorCallback($errorCode, $errorMessage, $errorDetails)';
}

class MockFastBarcodeScannerHostApi extends FastBarcodeScannerHostApi {
  final List<MethodCall> methodCalls = [];
  PreviewConfiguration? mockPreviewConfig;
  bool mockTorchResult = false;
  List<BarcodeData?> mockScanResults = [];
  String? mockCachedImagePath;

  MockFastBarcodeScannerHostApi({BinaryMessenger? binaryMessenger})
      : super(binaryMessenger: binaryMessenger);

  @override
  Future<PreviewConfiguration> initialize(
      ScannerConfiguration configuration) async {
    methodCalls.add(MethodCall('initialize', configuration));
    return mockPreviewConfig ??
        PreviewConfiguration(
          textureId: 1,
          targetRotation: 0,
          height: 480,
          width: 640,
          analysisWidth: 320,
          analysisHeight: 240,
        );
  }

  @override
  Future<void> start() async {
    methodCalls.add(const MethodCall('start'));
  }

  @override
  Future<void> stop() async {
    methodCalls.add(const MethodCall('stop'));
  }

  @override
  Future<void> startDetector() async {
    methodCalls.add(const MethodCall('startDetector'));
  }

  @override
  Future<void> stopDetector() async {
    methodCalls.add(const MethodCall('stopDetector'));
  }

  @override
  Future<void> dispose() async {
    methodCalls.add(const MethodCall('dispose'));
  }

  @override
  Future<bool> toggleTorch() async {
    methodCalls.add(const MethodCall('toggleTorch'));
    return mockTorchResult;
  }

  @override
  Future<PreviewConfiguration> changeConfiguration(
      UpdateConfiguration configuration) async {
    methodCalls.add(MethodCall('changeConfiguration', configuration));
    return mockPreviewConfig ??
        PreviewConfiguration(
          textureId: 1,
          targetRotation: 0,
          height: 720,
          width: 1280,
          analysisWidth: 640,
          analysisHeight: 360,
        );
  }

  @override
  Future<ScanData> scanImage(ImageSourceData imageSource) async {
    methodCalls.add(MethodCall('scanImage', imageSource));
    return ScanData(barcodes: mockScanResults);
  }

  @override
  Future<String?> retrieveCachedImage(String code) async {
    methodCalls.add(MethodCall('retrieveCachedImage', code));
    return mockCachedImagePath;
  }

  @override
  Future<void> clearCachedImage() async {
    methodCalls.add(const MethodCall('clearCachedImage'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FastBarcodeScannerHostApi', () {
    late MockFastBarcodeScannerHostApi mockApi;

    setUp(() {
      mockApi = MockFastBarcodeScannerHostApi();
    });

    test('should call initialize with correct configuration', () async {
      final config = ScannerConfiguration(
        types: [BarcodeType.qr, BarcodeType.code128],
        mode: DetectionMode.continuous,
        resolution: Resolution.hd720,
        framerate: Framerate.fps30,
        position: CameraPosition.back,
      );

      final result = await mockApi.initialize(config);

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('initialize'));
      expect(mockApi.methodCalls[0].arguments, equals(config));
      expect(result, isA<PreviewConfiguration>());
    });

    test('should call start method', () async {
      await mockApi.start();

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('start'));
      expect(mockApi.methodCalls[0].arguments, isNull);
    });

    test('should call stop method', () async {
      await mockApi.stop();

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('stop'));
    });

    test('should call startDetector method', () async {
      await mockApi.startDetector();

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('startDetector'));
    });

    test('should call stopDetector method', () async {
      await mockApi.stopDetector();

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('stopDetector'));
    });

    test('should call dispose method', () async {
      await mockApi.dispose();

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('dispose'));
    });

    test('should call toggleTorch and return result', () async {
      mockApi.mockTorchResult = true;

      final result = await mockApi.toggleTorch();

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('toggleTorch'));
      expect(result, isTrue);
    });

    test('should call changeConfiguration with update config', () async {
      final updateConfig = UpdateConfiguration(
        types: [BarcodeType.ean13],
        resolution: Resolution.hd1080,
      );

      final result = await mockApi.changeConfiguration(updateConfig);

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('changeConfiguration'));
      expect(mockApi.methodCalls[0].arguments, equals(updateConfig));
      expect(result, isA<PreviewConfiguration>());
    });

    test('should call scanImage with image source data', () async {
      final imageData = ImageSourceData(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        rotation: 90,
        useImagePicker: false,
      );

      mockApi.mockScanResults = [
        BarcodeData(type: BarcodeType.qr, value: 'test-qr'),
      ];

      final result = await mockApi.scanImage(imageData);

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('scanImage'));
      expect(mockApi.methodCalls[0].arguments, equals(imageData));
      expect(result.barcodes?.length, equals(1));
      expect(result.barcodes?[0]?.value, equals('test-qr'));
    });

    test('should call retrieveCachedImage with code', () async {
      const testCode = 'test-barcode-123';
      mockApi.mockCachedImagePath = '/path/to/cached/image.jpg';

      final result = await mockApi.retrieveCachedImage(testCode);

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('retrieveCachedImage'));
      expect(mockApi.methodCalls[0].arguments, equals(testCode));
      expect(result, equals('/path/to/cached/image.jpg'));
    });

    test('should call clearCachedImage', () async {
      await mockApi.clearCachedImage();

      expect(mockApi.methodCalls.length, equals(1));
      expect(mockApi.methodCalls[0].method, equals('clearCachedImage'));
    });
  });

  group('PigeonFastBarcodeScanner', () {
    late TestPigeonFastBarcodeScanner scanner;
    final List<List<ScannedItem>> detectedBarcodes = [];

    setUp(() {
      scanner = TestPigeonFastBarcodeScanner();
      detectedBarcodes.clear();
    });

    test('should set detection handler', () {
      scanner.setOnScannedItemDetectedHandler((barcodes) {
        detectedBarcodes.add(barcodes);
      });

      // Simulate barcode detection from native
      scanner.onScanDataDetected(ScanData(barcodes: [
        BarcodeData(type: BarcodeType.qr, value: 'test1'),
        BarcodeData(type: BarcodeType.code128, value: 'test2'),
      ]));

      expect(detectedBarcodes.length, equals(1));
      expect(detectedBarcodes[0].length, equals(2));
      expect(detectedBarcodes[0][0].value, equals('test1'));
      expect(detectedBarcodes[0][1].value, equals('test2'));
    });

    test('should filter out null barcodes in detection handler', () {
      scanner.setOnScannedItemDetectedHandler((barcodes) {
        detectedBarcodes.add(barcodes);
      });

      // Simulate barcode detection with null values
      scanner.onScanDataDetected(ScanData(barcodes: [
        BarcodeData(type: BarcodeType.qr, value: 'valid'),
        null,
        BarcodeData(type: BarcodeType.code128, value: 'also-valid'),
        null,
      ]));

      expect(detectedBarcodes.length, equals(1));
      expect(detectedBarcodes[0].length, equals(2));
      expect(detectedBarcodes[0][0].value, equals('valid'));
      expect(detectedBarcodes[0][1].value, equals('also-valid'));
    });

    test('should handle error callback', () {
      // Test basic error callback
      scanner.onError(
          'CAMERA_ERROR', 'Camera initialization failed', 'Additional details');

      expect(scanner.errorCallbacks.length, equals(1));
      expect(scanner.errorCallbacks[0].errorCode, equals('CAMERA_ERROR'));
      expect(scanner.errorCallbacks[0].errorMessage,
          equals('Camera initialization failed'));
      expect(
          scanner.errorCallbacks[0].errorDetails, equals('Additional details'));
    });

    test('should handle empty barcode detection', () {
      scanner.setOnScannedItemDetectedHandler((barcodes) {
        detectedBarcodes.add(barcodes);
      });

      scanner.onScanDataDetected(ScanData(barcodes: []));

      expect(detectedBarcodes.length, equals(1));
      expect(detectedBarcodes[0], isEmpty);
    });

    test('should handle null detection handler gracefully', () {
      // Don't set a handler
      expect(() {
        scanner.onScanDataDetected(ScanData(barcodes: [
          BarcodeData(type: BarcodeType.qr, value: 'test'),
        ]));
      }, returnsNormally);
    });
  });

  group('API Integration', () {
    test('should handle complete workflow', () async {
      final mockApi = MockFastBarcodeScannerHostApi();

      // Setup mock responses
      mockApi.mockPreviewConfig = PreviewConfiguration(
        textureId: 123,
        targetRotation: 90,
        height: 1080,
        width: 1920,
        analysisWidth: 540,
        analysisHeight: 960,
      );

      mockApi.mockScanResults = [
        BarcodeData(
          type: BarcodeType.qr,
          value: 'https://example.com',
          valueType: BarcodeValueType.url,
          cornerPoints: [
            PointData(x: 100, y: 100),
            PointData(x: 200, y: 100),
            PointData(x: 200, y: 200),
            PointData(x: 100, y: 200),
          ],
        ),
      ];

      // Test complete workflow
      final initConfig = ScannerConfiguration(
        types: [BarcodeType.qr, BarcodeType.code128],
        mode: DetectionMode.continuous,
        resolution: Resolution.hd1080,
        framerate: Framerate.fps60,
        position: CameraPosition.back,
        apiMode: IOSApiMode.vision,
        confidence: 0.8,
      );

      final previewConfig = await mockApi.initialize(initConfig);
      await mockApi.start();
      await mockApi.startDetector();

      final imageData = ImageSourceData(
        imageBytes: Uint8List.fromList([255, 216, 255]), // JPEG header
        rotation: 0,
        useImagePicker: false,
      );

      final scanData = await mockApi.scanImage(imageData);

      await mockApi.stopDetector();
      await mockApi.stop();
      await mockApi.dispose();

      // Verify results
      expect(previewConfig.textureId, equals(123));
      expect(scanData.barcodes?.length, equals(1));
      expect(scanData.barcodes?[0]?.type, equals(BarcodeType.qr));
      expect(scanData.barcodes?[0]?.value, equals('https://example.com'));
      expect(scanData.barcodes?[0]?.cornerPoints?.length, equals(4));

      // Verify all methods were called
      expect(mockApi.methodCalls.length, equals(7));
      expect(
          mockApi.methodCalls.map((call) => call.method),
          equals([
            'initialize',
            'start',
            'startDetector',
            'scanImage',
            'stopDetector',
            'stop',
            'dispose',
          ]));
    });
  });
}
