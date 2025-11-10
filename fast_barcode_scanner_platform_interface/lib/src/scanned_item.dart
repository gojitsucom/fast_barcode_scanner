import '../fast_barcode_scanner_platform_interface.dart';

abstract class ScannedItem<T> {
  T get item;
  String get type;
  String get value;
  List<PointData?>? get cornerPoints;
}

class ScannedBarcode extends ScannedItem<BarcodeData> {
  ScannedBarcode(this._barcode);
  final BarcodeData _barcode;

  @override
  String get value => _barcode.value;

  @override
  String get type => _barcode.type.toString();

  @override
  List<PointData?>? get cornerPoints => _barcode.cornerPoints;

  @override
  BarcodeData get item => _barcode;
}

class ScannedOcr extends ScannedItem<OCRData> {
  ScannedOcr(this._ocr);
  final OCRData _ocr;

  @override
  String get value => _ocr.text;

  @override
  String get type => 'ocr';

  @override
  List<PointData?>? get cornerPoints => _ocr.cornerPoints;

  @override
  OCRData get item => _ocr;
}
