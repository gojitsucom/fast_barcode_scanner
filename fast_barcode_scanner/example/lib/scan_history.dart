import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/cupertino.dart';

final history = ScanHistory();

class ScanHistory extends ChangeNotifier {
  final scans = <ScannedItem>[];
  final counter = <String, int>{};

  ScannedItem? get recent => scans.isNotEmpty ? scans.last : null;
  int count(ScannedItem of) => counter[of.value] ?? 0;

  void addAll(List<ScannedItem> items) {
    scans.addAll(items);
    for (final item in items) {
      counter.update(item.value, (value) => value + 1, ifAbsent: () => 1);
    }
    notifyListeners();
  }

  void clear() {
    scans.clear();
    counter.clear();
    notifyListeners();
  }
}

