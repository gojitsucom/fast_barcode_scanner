abstract class IOSApiMode {
  static const avFoundation = AVFoundationMode();
  static const visionStandard = VisionMode();

  const IOSApiMode();

  String get name;

  Map<String, dynamic> get configMap => {
        "apiMode": name,
        ...config,
      };

  Map<String, dynamic> get config => {};
}

class AVFoundationMode extends IOSApiMode {
  static const standardConfidence = 0.6;

  @override
  final String name = "avFoundation";

  /// The minimum confidence that the Vision API should use to filter scanned
  /// codes given as a number between 0..1
  ///
  /// defaults to 0.6
  final double confidence;

  const AVFoundationMode({this.confidence = standardConfidence});

  @override
  Map<String, dynamic> get config => {
        "confidence": confidence.clamp(0, 1),
      };
}

class VisionMode extends IOSApiMode {
  static const standardConfidence = 0.6;

  /// The minimum confidence that the Vision API should use to filter scanned
  /// codes given as a number between 0..1
  ///
  /// defaults to 0.6
  final double confidence;

  @override
  final String name = "vision";

  const VisionMode({this.confidence = standardConfidence});

  @override
  Map<String, dynamic> get config => {
        "confidence": confidence.clamp(0, 1),
      };
}
