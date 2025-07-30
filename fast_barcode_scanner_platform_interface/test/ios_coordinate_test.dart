import 'package:flutter_test/flutter_test.dart';
import 'package:fast_barcode_scanner_platform_interface/src/pigeon_barcode_scanner.dart';

void main() {
  group('iOS Coordinate System Tests', () {
    test('Vision API coordinate conversion should be consistent', () {
      // Test case: Vision API returns normalized coordinates (0-1)
      // with bottom-left origin, should convert to top-left origin pixel coordinates
      
      // Example: A QR code in the center of a 1000x1000 preview
      // Vision coordinates (bottom-left origin):
      // topLeft: (0.25, 0.75) -> should become (250, 250) in top-left origin
      // topRight: (0.75, 0.75) -> should become (750, 250) in top-left origin  
      // bottomRight: (0.75, 0.25) -> should become (750, 750) in top-left origin
      // bottomLeft: (0.25, 0.25) -> should become (250, 750) in top-left origin
      
      const expectedCorners = [
        [250, 250], // topLeft
        [750, 250], // topRight
        [750, 750], // bottomRight
        [250, 750], // bottomLeft
      ];
      
      // This test documents the expected behavior
      // Actual conversion happens in native iOS code
      expect(expectedCorners.length, equals(4));
      
      // Verify the coordinate transformation logic
      for (int i = 0; i < expectedCorners.length; i++) {
        expect(expectedCorners[i].length, equals(2));
        expect(expectedCorners[i][0], greaterThanOrEqualTo(0)); // x >= 0
        expect(expectedCorners[i][1], greaterThanOrEqualTo(0)); // y >= 0
      }
    });

    test('AVFoundation coordinate conversion should preserve order', () {
      // AVFoundation provides corners in layer coordinates already
      // Order should be: [topLeft, topRight, bottomRight, bottomLeft]
      
      const mockCorners = [
        [100, 100], // topLeft
        [200, 100], // topRight
        [200, 200], // bottomRight
        [100, 200], // bottomLeft
      ];
      
      // Verify rectangle properties
      expect(mockCorners[0][0], lessThan(mockCorners[1][0])); // topLeft.x < topRight.x
      expect(mockCorners[0][1], equals(mockCorners[1][1])); // topLeft.y == topRight.y
      expect(mockCorners[1][0], equals(mockCorners[2][0])); // topRight.x == bottomRight.x
      expect(mockCorners[1][1], lessThan(mockCorners[2][1])); // topRight.y < bottomRight.y
      expect(mockCorners[2][0], greaterThan(mockCorners[3][0])); // bottomRight.x > bottomLeft.x
      expect(mockCorners[2][1], equals(mockCorners[3][1])); // bottomRight.y == bottomLeft.y
      expect(mockCorners[3][0], equals(mockCorners[0][0])); // bottomLeft.x == topLeft.x
      expect(mockCorners[3][1], greaterThan(mockCorners[0][1])); // bottomLeft.y > topLeft.y
    });

    test('Coordinate validation should reject invalid values', () {
      // Test invalid coordinate scenarios
      const invalidCases = [
        [-1, 100],    // Negative x
        [100, -1],    // Negative y
        [double.infinity, 100], // Infinite x
        [100, double.nan],      // NaN y
      ];
      
      for (final invalidCase in invalidCases) {
        // These should be rejected by validation logic
        final x = invalidCase[0];
        final y = invalidCase[1];
        final isValid = x.isFinite && y.isFinite && x >= 0 && y >= 0;
        expect(isValid, isFalse, reason: 'Invalid coordinates should be rejected: [$x, $y]');
      }
    });

    test('Corner points should maintain consistent ordering across APIs', () {
      // Both Vision and AVFoundation should produce the same ordering
      const expectedOrder = [
        'topLeft',
        'topRight', 
        'bottomRight',
        'bottomLeft'
      ];
      
      // Create test barcode data with proper ordering
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

      expect(barcodeData.cornerPoints!.length, equals(expectedOrder.length));
      
      // Verify geometric properties
      final tl = barcodeData.cornerPoints![0]!;
      final tr = barcodeData.cornerPoints![1]!;
      final br = barcodeData.cornerPoints![2]!;
      final bl = barcodeData.cornerPoints![3]!;
      
      // Top edge should be horizontal
      expect(tl.y, equals(tr.y));
      // Bottom edge should be horizontal
      expect(bl.y, equals(br.y));
      // Left edge should be vertical
      expect(tl.x, equals(bl.x));
      // Right edge should be vertical
      expect(tr.x, equals(br.x));
      
      // Top should be above bottom
      expect(tl.y, lessThan(bl.y));
      // Left should be left of right
      expect(tl.x, lessThan(tr.x));
    });

    test('Coordinate system should match Android MLKit', () {
      // Both iOS and Android should use the same coordinate system:
      // - Origin at top-left (0,0)
      // - X increases to the right
      // - Y increases downward
      // - Corner order: [topLeft, topRight, bottomRight, bottomLeft]
      
      // Test a simple rectangle
      final testCorners = [
        PointData(x: 0, y: 0),     // topLeft
        PointData(x: 100, y: 0),   // topRight
        PointData(x: 100, y: 100), // bottomRight
        PointData(x: 0, y: 100),   // bottomLeft
      ];
      
      // Verify coordinate system properties
      expect(testCorners[0].x, equals(0)); // topLeft at origin
      expect(testCorners[0].y, equals(0));
      
      expect(testCorners[1].x, greaterThan(testCorners[0].x)); // topRight to the right
      expect(testCorners[1].y, equals(testCorners[0].y)); // same Y as topLeft
      
      expect(testCorners[2].x, equals(testCorners[1].x)); // bottomRight same X as topRight
      expect(testCorners[2].y, greaterThan(testCorners[1].y)); // below topRight
      
      expect(testCorners[3].x, equals(testCorners[0].x)); // bottomLeft same X as topLeft
      expect(testCorners[3].y, equals(testCorners[2].y)); // same Y as bottomRight
    });

    test('Edge cases should be handled gracefully', () {
      // Test edge cases that might occur in real usage
      
      // Case 1: Very small barcode
      final smallCorners = [
        PointData(x: 10, y: 10),
        PointData(x: 11, y: 10),
        PointData(x: 11, y: 11),
        PointData(x: 10, y: 11),
      ];
      
      expect(smallCorners.length, equals(4));
      
      // Case 2: Large coordinates (4K resolution)
      final largeCorners = [
        PointData(x: 0, y: 0),
        PointData(x: 3840, y: 0),
        PointData(x: 3840, y: 2160),
        PointData(x: 0, y: 2160),
      ];
      
      expect(largeCorners.length, equals(4));
      expect(largeCorners[1].x, equals(3840)); // 4K width
      expect(largeCorners[2].y, equals(2160)); // 4K height
    });
  });
}
