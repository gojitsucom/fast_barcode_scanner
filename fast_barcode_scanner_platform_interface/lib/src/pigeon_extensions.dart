import 'dart:math' as dart_math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'pigeon_barcode_scanner.dart';

/// Extensions for Resolution enum to provide width and height values
extension ResolutionExtension on Resolution {
  /// Width in pixels for this resolution
  int get width {
    switch (this) {
      case Resolution.sd480:
        return 720;
      case Resolution.hd720:
        return 1280;
      case Resolution.hd1080:
        return 1920;
      case Resolution.hd4k:
        return 3840;
    }
  }

  /// Height in pixels for this resolution
  int get height {
    switch (this) {
      case Resolution.sd480:
        return 480;
      case Resolution.hd720:
        return 960;
      case Resolution.hd1080:
        return 1080;
      case Resolution.hd4k:
        return 2160;
    }
  }

  /// String representation of the resolution
  String get displayName {
    switch (this) {
      case Resolution.sd480:
        return '480p';
      case Resolution.hd720:
        return '720p';
      case Resolution.hd1080:
        return '1080p';
      case Resolution.hd4k:
        return '4K';
    }
  }
}

/// Extensions for Framerate enum to provide numeric values
extension FramerateExtension on Framerate {
  /// Numeric value of the framerate
  double get value {
    switch (this) {
      case Framerate.fps30:
        return 30.0;
      case Framerate.fps60:
        return 60.0;
      case Framerate.fps120:
        return 120.0;
      case Framerate.fps240:
        return 240.0;
    }
  }

  /// String representation of the framerate
  String get displayName {
    switch (this) {
      case Framerate.fps30:
        return '30 FPS';
      case Framerate.fps60:
        return '60 FPS';
      case Framerate.fps120:
        return '120 FPS';
      case Framerate.fps240:
        return '240 FPS';
    }
  }
}

/// Extensions for BarcodeType enum
extension BarcodeTypeExtension on BarcodeType {
  /// String representation for native platforms
  String get nativeName {
    switch (this) {
      case BarcodeType.aztec:
        return 'aztec';
      case BarcodeType.code128:
        return 'code128';
      case BarcodeType.code39:
        return 'code39';
      case BarcodeType.code39mod43:
        return 'code39mod43';
      case BarcodeType.code93:
        return 'code93';
      case BarcodeType.codabar:
        return 'codabar';
      case BarcodeType.dataMatrix:
        return 'dataMatrix';
      case BarcodeType.ean13:
        return 'ean13';
      case BarcodeType.ean8:
        return 'ean8';
      case BarcodeType.itf:
        return 'itf';
      case BarcodeType.pdf417:
        return 'pdf417';
      case BarcodeType.qr:
        return 'qr';
      case BarcodeType.upcA:
        return 'upcA';
      case BarcodeType.upcE:
        return 'upcE';
      case BarcodeType.interleaved:
        return 'interleaved';
    }
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case BarcodeType.aztec:
        return 'Aztec';
      case BarcodeType.code128:
        return 'Code 128';
      case BarcodeType.code39:
        return 'Code 39';
      case BarcodeType.code39mod43:
        return 'Code 39 Mod 43';
      case BarcodeType.code93:
        return 'Code 93';
      case BarcodeType.codabar:
        return 'Codabar';
      case BarcodeType.dataMatrix:
        return 'Data Matrix';
      case BarcodeType.ean13:
        return 'EAN-13';
      case BarcodeType.ean8:
        return 'EAN-8';
      case BarcodeType.itf:
        return 'ITF';
      case BarcodeType.pdf417:
        return 'PDF417';
      case BarcodeType.qr:
        return 'QR Code';
      case BarcodeType.upcA:
        return 'UPC-A';
      case BarcodeType.upcE:
        return 'UPC-E';
      case BarcodeType.interleaved:
        return 'Interleaved 2 of 5';
    }
  }
}

/// Extensions for CameraPosition enum
extension CameraPositionExtension on CameraPosition {
  /// String representation for native platforms
  String get nativeName {
    switch (this) {
      case CameraPosition.front:
        return 'front';
      case CameraPosition.back:
        return 'back';
    }
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case CameraPosition.front:
        return 'Front Camera';
      case CameraPosition.back:
        return 'Back Camera';
    }
  }
}

/// Extensions for DetectionMode enum
extension DetectionModeExtension on DetectionMode {
  /// String representation for native platforms
  String get nativeName {
    switch (this) {
      case DetectionMode.pauseDetection:
        return 'pauseDetection';
      case DetectionMode.pauseVideo:
        return 'pauseVideo';
      case DetectionMode.continuous:
        return 'continuous';
    }
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case DetectionMode.pauseDetection:
        return 'Pause Detection';
      case DetectionMode.pauseVideo:
        return 'Pause Video';
      case DetectionMode.continuous:
        return 'Continuous';
    }
  }
}

/// Extensions for IOSApiMode enum
extension IOSApiModeExtension on IOSApiMode {
  /// String representation for native platforms
  String get nativeName {
    switch (this) {
      case IOSApiMode.avFoundation:
        return 'avFoundation';
      case IOSApiMode.vision:
        return 'vision';
    }
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case IOSApiMode.avFoundation:
        return 'AVFoundation';
      case IOSApiMode.vision:
        return 'Vision';
    }
  }
}



/// Extensions for ImageSourceData
extension ImageSourceDataExtension on ImageSourceData {
  /// Create ImageSourceData from binary data
  static ImageSourceData binary(List<int> bytes, {int? rotation}) {
    return ImageSourceData(
      imageBytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      rotation: rotation,
      useImagePicker: false,
    );
  }

  /// Create ImageSourceData using image picker
  static ImageSourceData picker() {
    return ImageSourceData(
      imageBytes: null,
      rotation: null,
      useImagePicker: true,
    );
  }
}

/// Extensions for ScannerConfiguration
extension ScannerConfigurationExtension on ScannerConfiguration {
  /// Create a copy of this configuration with some fields replaced
  ScannerConfiguration copyWith({
    List<BarcodeType>? types,
    DetectionMode? mode,
    Resolution? resolution,
    Framerate? framerate,
    CameraPosition? position,
    IOSApiMode? apiMode,
    double? confidence,
    bool? enableOcr,
  }) {
    return ScannerConfiguration(
      types: types ?? this.types,
      mode: mode ?? this.mode,
      resolution: resolution ?? this.resolution,
      framerate: framerate ?? this.framerate,
      position: position ?? this.position,
      apiMode: apiMode ?? this.apiMode,
      confidence: confidence ?? this.confidence,
      enableOcr: enableOcr ?? this.enableOcr,
    );
  }
}

/// Extensions for UpdateConfiguration
extension UpdateConfigurationExtension on UpdateConfiguration {
  /// Create a copy of this configuration with some fields replaced
  UpdateConfiguration copyWith({
    List<BarcodeType?>? types,
    DetectionMode? mode,
    Resolution? resolution,
    Framerate? framerate,
    CameraPosition? position,
    bool? enableOcr,
  }) {
    return UpdateConfiguration(
      types: types ?? this.types,
      mode: mode ?? this.mode,
      resolution: resolution ?? this.resolution,
      framerate: framerate ?? this.framerate,
      position: position ?? this.position,
      enableOcr: enableOcr ?? this.enableOcr,
    );
  }
}

/// Extensions for PreviewConfiguration
extension PreviewConfigurationExtension on PreviewConfiguration {
  /// Analysis resolution as a string
  String get analysisResolution => '${analysisWidth}x$analysisHeight';

  /// Create a copy of this configuration with some fields replaced
  PreviewConfiguration copyWith({
    int? textureId,
    int? targetRotation,
    int? height,
    int? width,
    int? analysisWidth,
    int? analysisHeight,
  }) {
    return PreviewConfiguration(
      textureId: textureId ?? this.textureId,
      targetRotation: targetRotation ?? this.targetRotation,
      height: height ?? this.height,
      width: width ?? this.width,
      analysisWidth: analysisWidth ?? this.analysisWidth,
      analysisHeight: analysisHeight ?? this.analysisHeight,
    );
  }
}

/// Extensions for BarcodeData
extension BarcodeDataExtension on BarcodeData {
  /// Create a copy of this barcode with some fields replaced
  BarcodeData copyWith({
    BarcodeType? type,
    String? value,
    BarcodeValueType? valueType,
    List<PointData?>? cornerPoints,
  }) {
    return BarcodeData(
      type: type ?? this.type,
      value: value ?? this.value,
      valueType: valueType ?? this.valueType,
      cornerPoints: cornerPoints ?? this.cornerPoints,
    );
  }

  /// Check if this barcode has corner points
  bool get hasCornerPoints => cornerPoints != null && cornerPoints!.isNotEmpty;

  /// Get valid corner points (non-null)
  List<PointData> get validCornerPoints {
    return cornerPoints?.whereType<PointData>().toList() ?? [];
  }
}

/// Extensions for PointData
extension PointDataExtension on PointData {
  /// Create a copy of this point with some fields replaced
  PointData copyWith({
    int? x,
    int? y,
  }) {
    return PointData(
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  /// Convert to a string representation
  String toStringRepresentation() => 'PointData(x: $x, y: $y)';

  /// Calculate distance to another point
  double distanceTo(PointData other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return dart_math.sqrt((dx * dx + dy * dy).toDouble());
  }

  /// Convert to Flutter Offset
  Offset toOffset() => Offset(x.toDouble(), y.toDouble());
}
