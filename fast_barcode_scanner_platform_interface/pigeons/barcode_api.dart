import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/pigeon_barcode_scanner.dart',
  dartOptions: DartOptions(),
  kotlinOut: '../fast_barcode_scanner/android/src/main/kotlin/com/jhoogstraat/fast_barcode_scanner/pigeon/BarcodeApi.kt',
  kotlinOptions: KotlinOptions(
    package: 'com.jhoogstraat.fast_barcode_scanner.pigeon',
  ),
  swiftOut: '../fast_barcode_scanner/ios/Classes/pigeon/BarcodeApi.swift',
  swiftOptions: SwiftOptions(),
  dartPackageName: 'fast_barcode_scanner_platform_interface',
))

/// Enum representing different barcode types
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

/// Enum representing barcode value types (Android only)
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

/// Enum representing camera resolutions
enum Resolution {
  sd480,
  hd720,
  hd1080,
  hd4k,
}

/// Enum representing camera framerates
enum Framerate {
  fps30,
  fps60,
  fps120,
  fps240,
}

/// Enum representing detection modes
enum DetectionMode {
  pauseDetection,
  pauseVideo,
  continuous,
}

/// Enum representing camera positions
enum CameraPosition {
  front,
  back,
}

/// Enum representing iOS API modes
enum IOSApiMode {
  avFoundation,
  vision,
}

/// Represents a point with x and y coordinates
class PointData {
  PointData({required this.x, required this.y});

  final int x;
  final int y;
}

/// Represents a detected barcode
class Barcode {
  Barcode({
    required this.type,
    required this.value,
    this.valueType,
    this.cornerPoints,
  });

  final BarcodeType type;
  final String value;
  final BarcodeValueType? valueType;
  final List<PointData?>? cornerPoints;
}

/// Configuration for camera preview
class PreviewConfiguration {
  PreviewConfiguration({
    required this.textureId,
    required this.targetRotation,
    required this.height,
    required this.width,
    required this.analysisWidth,
    required this.analysisHeight,
  });

  final int textureId;
  final int targetRotation;
  final int height;
  final int width;
  final int analysisWidth;
  final int analysisHeight;
}

/// Configuration for initializing the scanner
class ScannerConfiguration {
  ScannerConfiguration({
    required this.types,
    required this.mode,
    required this.resolution,
    required this.framerate,
    required this.position,
    this.apiMode,
    this.confidence,
  });

  final List<BarcodeType?> types;
  final DetectionMode mode;
  final Resolution resolution;
  final Framerate framerate;
  final CameraPosition position;
  final IOSApiMode? apiMode;
  final double? confidence;
}

/// Configuration for updating scanner settings
class UpdateConfiguration {
  UpdateConfiguration({
    this.types,
    this.mode,
    this.resolution,
    this.framerate,
    this.position,
  });

  final List<BarcodeType?>? types;
  final DetectionMode? mode;
  final Resolution? resolution;
  final Framerate? framerate;
  final CameraPosition? position;
}

/// Data for image scanning
class ImageSourceData {
  ImageSourceData({
    this.imageBytes,
    this.rotation,
    this.useImagePicker = false,
  });

  final Uint8List? imageBytes;
  final int? rotation;
  final bool useImagePicker;
}

/// Host API for communication from Dart to native platforms
@HostApi()
abstract class FastBarcodeScannerHostApi {
  /// Initialize the camera and scanner with the given configuration
  @async
  PreviewConfiguration initialize(ScannerConfiguration configuration);

  /// Start the camera
  @async
  void start();

  /// Stop the camera
  @async
  void stop();

  /// Start the barcode detector
  @async
  void startDetector();

  /// Stop the barcode detector
  @async
  void stopDetector();

  /// Dispose camera resources
  @async
  void dispose();

  /// Toggle the camera torch/flash
  @async
  bool toggleTorch();

  /// Update scanner configuration
  @async
  PreviewConfiguration changeConfiguration(UpdateConfiguration configuration);

  /// Scan barcode from image
  @async
  List<Barcode?> scanImage(ImageSourceData imageSource);

  /// Retrieve cached image path for a barcode
  @async
  String? retrieveCachedImage(String code);

  /// Clear all cached images
  @async
  void clearCachedImage();
}

/// Flutter API for communication from native platforms to Dart
@FlutterApi()
abstract class FastBarcodeScannerFlutterApi {
  /// Called when barcodes are detected
  void onBarcodesDetected(List<Barcode?> barcodes);

  /// Called when an error occurs
  void onError(String errorCode, String errorMessage, String? errorDetails);
}
