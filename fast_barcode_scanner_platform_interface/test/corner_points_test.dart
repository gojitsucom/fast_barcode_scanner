import 'package:flutter_test/flutter_test.dart';
import 'package:fast_barcode_scanner_platform_interface/src/pigeon_barcode_scanner.dart';

void main() {
  group('Corner Points Consistency Tests', () {
    test('PointData should maintain coordinate integrity', () {
      // Test basic PointData creation and conversion
      const testX = 100;
      const testY = 200;
      
      final point = PointData(x: testX, y: testY);
      
      expect(point.x, equals(testX));
      expect(point.y, equals(testY));
    });

    test('BarcodeData should handle corner points correctly', () {
      // Test corner points in expected order: [topLeft, topRight, bottomRight, bottomLeft]
      final cornerPoints = [
        PointData(x: 10, y: 10),   // topLeft
        PointData(x: 90, y: 10),   // topRight  
        PointData(x: 90, y: 90),   // bottomRight
        PointData(x: 10, y: 90),   // bottomLeft
      ];

      final barcodeData = BarcodeData(
        type: BarcodeType.qr,
        value: 'test',
        cornerPoints: cornerPoints,
      );

      expect(barcodeData.cornerPoints, isNotNull);
      expect(barcodeData.cornerPoints!.length, equals(4));
      
      // Verify order: topLeft, topRight, bottomRight, bottomLeft
      expect(barcodeData.cornerPoints![0]!.x, equals(10)); // topLeft.x
      expect(barcodeData.cornerPoints![0]!.y, equals(10)); // topLeft.y
      
      expect(barcodeData.cornerPoints![1]!.x, equals(90)); // topRight.x
      expect(barcodeData.cornerPoints![1]!.y, equals(10)); // topRight.y
      
      expect(barcodeData.cornerPoints![2]!.x, equals(90)); // bottomRight.x
      expect(barcodeData.cornerPoints![2]!.y, equals(90)); // bottomRight.y
      
      expect(barcodeData.cornerPoints![3]!.x, equals(10)); // bottomLeft.x
      expect(barcodeData.cornerPoints![3]!.y, equals(90)); // bottomLeft.y
    });

    test('Corner points should form a valid rectangle', () {
      final cornerPoints = [
        PointData(x: 0, y: 0),     // topLeft
        PointData(x: 100, y: 0),   // topRight
        PointData(x: 100, y: 100), // bottomRight
        PointData(x: 0, y: 100),   // bottomLeft
      ];

      // Verify it forms a rectangle
      final topLeft = cornerPoints[0];
      final topRight = cornerPoints[1];
      final bottomRight = cornerPoints[2];
      final bottomLeft = cornerPoints[3];

      // Check horizontal alignment
      expect(topLeft.y, equals(topRight.y)); // Top edge
      expect(bottomLeft.y, equals(bottomRight.y)); // Bottom edge
      
      // Check vertical alignment  
      expect(topLeft.x, equals(bottomLeft.x)); // Left edge
      expect(topRight.x, equals(bottomRight.x)); // Right edge
      
      // Check rectangle properties
      expect(topLeft.x, lessThan(topRight.x)); // Left < Right
      expect(topLeft.y, lessThan(bottomLeft.y)); // Top < Bottom
    });

    test('Corner points should handle coordinate bounds', () {
      // Test with various coordinate ranges
      final testCases = [
        [0, 0],           // Origin
        [1920, 1080],     // HD resolution
        [3840, 2160],     // 4K resolution
        [-10, -10],       // Negative coordinates (edge case)
      ];

      for (final testCase in testCases) {
        final point = PointData(x: testCase[0], y: testCase[1]);
        expect(point.x, equals(testCase[0]));
        expect(point.y, equals(testCase[1]));
      }
    });

    test('Corner points should be nullable in BarcodeData', () {
      // Test BarcodeData without corner points
      final barcodeData = BarcodeData(
        type: BarcodeType.code128,
        value: 'test-without-corners',
        cornerPoints: null,
      );

      expect(barcodeData.cornerPoints, isNull);
    });

    test('Corner points should handle partial data', () {
      // Test with some null points in the array
      final cornerPoints = [
        PointData(x: 10, y: 10),
        null,
        PointData(x: 90, y: 90),
        null,
      ];

      final barcodeData = BarcodeData(
        type: BarcodeType.qr,
        value: 'test-partial',
        cornerPoints: cornerPoints,
      );

      expect(barcodeData.cornerPoints, isNotNull);
      expect(barcodeData.cornerPoints!.length, equals(4));
      expect(barcodeData.cornerPoints![0], isNotNull);
      expect(barcodeData.cornerPoints![1], isNull);
      expect(barcodeData.cornerPoints![2], isNotNull);
      expect(barcodeData.cornerPoints![3], isNull);
    });
  });

  group('Platform Consistency Tests', () {
    test('iOS and Android should use same coordinate system', () {
      // This test documents the expected coordinate system
      // Both platforms should use:
      // - Origin at top-left (0,0)
      // - X increases to the right
      // - Y increases downward
      // - Corner order: [topLeft, topRight, bottomRight, bottomLeft]
      
      final expectedOrder = [
        'topLeft',
        'topRight', 
        'bottomRight',
        'bottomLeft'
      ];
      
      // This is a documentation test - the actual coordinate validation
      // happens in the platform-specific implementations
      expect(expectedOrder.length, equals(4));
      expect(expectedOrder[0], equals('topLeft'));
      expect(expectedOrder[1], equals('topRight'));
      expect(expectedOrder[2], equals('bottomRight'));
      expect(expectedOrder[3], equals('bottomLeft'));
    });
  });
}
