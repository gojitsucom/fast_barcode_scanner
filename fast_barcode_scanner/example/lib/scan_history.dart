import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/cupertino.dart';

final history = ScanHistory();

class ScanHistory extends ChangeNotifier {
  final scans = <BarcodeData>[];
  final counter = <String, int>{};

  BarcodeData? get recent => scans.isNotEmpty ? scans.last : null;
  int count(BarcodeData of) => counter[of.value] ?? 0;

  void addAll(List<BarcodeData> barcodes) {
    scans.addAll(barcodes);
    for (final barcode in barcodes) {
      counter.update(barcode.value, (value) => value + 1, ifAbsent: () => 1);
    }
    notifyListeners();
  }

  void clear() {
    scans.clear();
    counter.clear();
    notifyListeners();
  }
}
