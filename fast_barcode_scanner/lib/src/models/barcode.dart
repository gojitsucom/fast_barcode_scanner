import '../generated/scanner_platform_interface.g.dart';

/// Describes a Barcode with type and value.
/// [Barcode] is value-equatable.
class Barcode {
  /// Creates a [Barcode] from a Flutter Message Protocol
  Barcode(List<dynamic> data)
      : type = BarcodeType.values.firstWhere((e) => e.toString().split('.').last == data[0]),
        value = data[1],
        valueType = data.length > 2
            ? data[2] != null
                ? BarcodeValueType.values[data[2]]
                : null
            : null,
        cornerPoints = data.length > 3 ? parsePointList(data[3]) : null;

  /// Creates a [Barcode] from a [BarcodeData] object
  factory Barcode.fromBarcodeData(BarcodeData data) {
    return Barcode([
      data.type.toString().split('.').last,
      data.value,
      data.valueType?.index,
      data.cornerPoints?.map((p) => [p.x, p.y]).toList(),
    ]);
  }

  /// The type of the barcode.
  final BarcodeType type;

  /// The actual value of the barcode.
  final String value;

  /// The type of content of the barcode.
  final BarcodeValueType? valueType;

  /// The corners of the visible barcode. This can be used for custom drawing.
  final List<Point>? cornerPoints;

  static List<Point>? parsePointList(List<dynamic>? pointList) {
    return pointList?.map((e) => Point(x: e[0], y: e[1])).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is Barcode &&
      other.type == type &&
      other.value == value &&
      other.valueType == valueType &&
      other.cornerPoints == cornerPoints;

  @override
  int get hashCode =>
      Object.hash(type, value, valueType, cornerPoints);

  @override
  String toString() {
    return '''
    Barcode {
      type: $type,
      value: $value,
      valueType: $valueType,
      rect: $cornerPoints
    }
    ''';
  }
}
