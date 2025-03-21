import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/generated/scanner_platform_interface.g.dart',
  dartOptions: DartOptions(),
  swiftOut: 'ios/Classes/Generated/ScannerPlatformInterface.g.swift',
  swiftOptions: SwiftOptions(),
  kotlinOut:
      'android/src/main/kotlin/com/jhoogstraat/fast_barcode_scanner/Generated/ScannerPlatformInterface.g.kt',
  kotlinOptions: KotlinOptions(),
  dartPackageName: 'fast_barcode_scanner',
  input: 'pigeon/scanner_platform_interface.dart',
))
@HostApi()
abstract class ScannerPlatformInterface {
  @async
  PreviewConfiguration initialize({
    required List<BarcodeType> types,
    required Resolution resolution,
    required Framerate framerate,
    required DetectionMode detectionMode,
    required CameraPosition position,
    Map<String, dynamic>? apiMode,
  });

  @async
  void start();

  @async
  void stop();

  @async
  void startDetector();

  @async
  void stopDetector();

  @async
  bool toggleTorch();

  @async
  PreviewConfiguration updateConfiguration({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
  });

  @async
  void dispose();

  @async
  String? retrieveCachedImage(String code);

  @async
  void clearCachedImage();
}

@FlutterApi()
abstract class BarcodeDetectionHandler {
  void onBarcodeDetected(List<dynamic> data);
}

/// Supported resolutions. Not all devices support all resolutions!
enum Resolution { sd480, hd720, hd1080, hd4k }

/// Supported Framerates. Not all devices support all framerates!
enum Framerate { fps30, fps60, fps120, fps240 }

/// Dictates how the camera reacts to detections
enum DetectionMode {
  /// Pauses the detection of further barcodes when a barcode is detected.
  /// The camera feed continues.
  pauseDetection,

  /// Pauses the camera feed on detection.
  /// This will inevitably stop the detection of barcodes.
  pauseVideo,

  /// Does nothing on detection. May need to throttle detections using continuous.
  continuous
}

/// The position of the camera.
enum CameraPosition { front, back }

/// The configuration by which the camera feed can be laid out in the UI.
class PreviewConfiguration {
  /// The width of the camera feed in points.
  final int width;

  /// The height of the camera feed in points.
  final int height;

  /// Expresses how many quarters the texture has to be rotated to be upright
  /// in clockwise direction.
  final int targetRotation;

  /// A id of a texture which contains the camera feed.
  ///
  /// Can be consumed by a [Texture] widget.
  final int textureId;

  /// The resolution which is used when scanning for barcodes.
  late final String analysisResolution;

  /// The width of the image used for analysis. This may be different than the preview width
  final int analysisWidth;

  /// The height of the image used for analysis. This may be different than the preview height
  final int analysisHeight;

  PreviewConfiguration(
      {required this.width,
      required this.height,
      required this.targetRotation,
      required this.textureId,
      required this.analysisWidth,
      required this.analysisHeight});
}

/// Contains all currently on iOS and Android supported barcode types.
enum BarcodeType {
  /// Android, iOS
  aztec,

  /// Android, iOS
  code128,

  /// Android, iOS
  code39,

  /// iOS
  code39mod43,

  /// Android, iOS
  code93,

  /// Android
  codabar,

  /// Android, iOS
  dataMatrix,

  /// Android, iOS
  ean13,

  /// Android, iOS
  ean8,

  /// Android, iOS
  itf,

  /// Android, iOS
  pdf417,

  /// Android, iOS
  qr,

  /// Android, iOS
  upcA,

  /// Android, iOS
  upcE,

  /// iOS
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
  license
}
