import 'dart:typed_data';

import '../generated/scanner_platform_interface.g.dart';

/// Describes the source of an image to be scanned.
class ImageSource {
  /// Creates an [ImageSource] from a Flutter Message Protocol
  const ImageSource(this.data);

  /// Creates an [ImageSource] from a binary image
  factory ImageSource.fromBinary(Uint8List bytes, {int rotation = 0}) {
    return ImageSource([bytes, rotation]);
  }

  /// Creates an [ImageSource] from the image picker
  factory ImageSource.fromPicker() {
    return const ImageSource(null);
  }

  /// The data of the image source.
  /// If [data] is null, the image will be picked from the gallery.
  /// If [data] is not null, it should be a list with two elements:
  /// - The first element is the image data as a [Uint8List].
  /// - The second element is the rotation of the image in degrees.
  final List<dynamic>? data;

  /// Converts this [ImageSource] to an [ImageData] object
  ImageData toImageData() {
    return ImageData(
      bytes: data != null ? (data![0] as Uint8List).toList() : null,
      rotation: data != null ? data![1] as int : 0,
      isFromPicker: data == null,
    );
  }
}
