// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:pigeon/pigeon.dart';

// Configuration for code generation
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/scanner_platform_interface.g.dart',
    dartOptions: DartOptions(
      copyrightHeader: ['// Copyright 2023 The Flutter Authors. All rights reserved.'],
    ),
    kotlinOut:
        'android/src/main/kotlin/com/jhoogstraat/fast_barcode_scanner/PigeonFastBarcodeScannerPlugin.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.jhoogstraat.fast_barcode_scanner',
    ),
    swiftOut: 'ios/Classes/PigeonFastBarcodeScannerPlugin.swift',
    swiftOptions: SwiftOptions(),
    objcHeaderOut: 'ios/Classes/PigeonFastBarcodeScannerPlugin.h',
    objcSourceOut: 'ios/Classes/PigeonFastBarcodeScannerPlugin.m',
    objcOptions: ObjcOptions(
      prefix: 'FBS',
    ),
  ),
)

// Enums
enum BarcodeType {
  aztec,
  code128,
  code39,
  code39mod43,
  code93,
  codabar,
  dataMatrix,
  ean13,
  ean8,
  itf,
  pdf417,
  qr,
  upcA,
  upcE,
  interleaved,
}

enum BarcodeValueType {
  unknown,
  contactInfo,
  email,
  isbn,
  phone,
  product,
  sms,
  text,
  url,
  wifi,
  geo,
  calender,
  license,
}

enum Resolution {
  sd480,
  hd720,
  hd1080,
  hd4k,
}

enum Framerate {
  fps30,
  fps60,
  fps120,
  fps240,
}

enum DetectionMode {
  pauseDetection,
  pauseVideo,
  continuous,
}

enum CameraPosition {
  front,
  back,
}

enum ApiMode {
  avFoundation,
  vision,
}

// Data classes
class Point {
  const Point(this.x, this.y);
  final int x;
  final int y;
}

class BarcodeData {
  const BarcodeData({
    required this.type,
    required this.value,
    this.valueType,
    this.cornerPoints,
  });
  final BarcodeType type;
  final String value;
  final BarcodeValueType? valueType;
  final List<Point>? cornerPoints;
}

class PreviewConfiguration {
  const PreviewConfiguration({
    required this.width,
    required this.height,
    required this.targetRotation,
    required this.textureId,
    this.analysisResolution,
    this.analysisWidth = 0,
    this.analysisHeight = 0,
  });
  final int width;
  final int height;
  final int targetRotation;
  final int textureId;
  final String? analysisResolution;
  final int analysisWidth;
  final int analysisHeight;
}

class ApiModeConfig {
  const ApiModeConfig({
    required this.apiMode,
    this.confidence = 0.6,
  });
  final ApiMode apiMode;
  final double confidence;
}

class ScannerConfiguration {
  const ScannerConfiguration({
    required this.types,
    required this.resolution,
    required this.framerate,
    required this.detectionMode,
    required this.position,
    this.apiModeConfig,
  });
  final List<BarcodeType> types;
  final Resolution resolution;
  final Framerate framerate;
  final DetectionMode detectionMode;
  final CameraPosition position;
  final ApiModeConfig? apiModeConfig;
}

class ImageData {
  const ImageData({
    this.bytes,
    this.rotation = 0,
    this.isFromPicker = false,
  });
  final Uint8List? bytes;
  final int rotation;
  final bool isFromPicker;
}

// Host API - implemented on the native side, called from Flutter
@HostApi()
abstract class BarcodeScannerHostApi {
  // Initialize the camera with the given configuration
  PreviewConfiguration initialize(ScannerConfiguration config);

  // Camera control methods
  void start();
  void stop();
  void startDetector();
  void stopDetector();
  void dispose();

  // Camera configuration
  bool toggleTorch();
  PreviewConfiguration updateConfiguration(ScannerConfiguration config);

  // Image scanning
  List<BarcodeData>? scanImage(ImageData imageData);

  // Image caching
  String? retrieveCachedImage(String code);
  void clearCachedImage();
}

// Flutter API - implemented on the Flutter side, called from native
@FlutterApi()
abstract class BarcodeScannerFlutterApi {
  // Called when barcodes are detected
  void onBarcodeDetection(List<BarcodeData> barcodes);

  // Called when an error occurs
  void onError(String errorMessage);
}
