import 'package:flutter/painting.dart';

import 'pigeon_barcode_scanner.dart';

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
  }) {
    return ScannerConfiguration(
      types: types ?? this.types,
      mode: mode ?? this.mode,
      resolution: resolution ?? this.resolution,
      framerate: framerate ?? this.framerate,
      position: position ?? this.position,
      apiMode: apiMode ?? this.apiMode,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// Extensions for PointData
extension PointDataExtension on PointData {
  /// Convert to Flutter Offset
  Offset toOffset() => Offset(x.toDouble(), y.toDouble());
}
