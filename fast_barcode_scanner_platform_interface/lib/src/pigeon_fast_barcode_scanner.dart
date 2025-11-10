import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';

import 'fast_barcode_scanner_platform_interface.dart';
import 'pigeon_barcode_scanner.dart';

/// Implementation of [FastBarcodeScannerPlatform] using Pigeon.
class PigeonFastBarcodeScanner extends FastBarcodeScannerPlatform
    implements FastBarcodeScannerFlutterApi {
  static final FastBarcodeScannerHostApi _hostApi = FastBarcodeScannerHostApi();

  OnScanDetectedHandler? _onScanDetectedHandler;

  /// Registers this class as the default instance of [FastBarcodeScannerPlatform].
  static void registerWith() {
    FastBarcodeScannerPlatform.instance = PigeonFastBarcodeScanner();
  }

  PigeonFastBarcodeScanner() {
    // Set up the Flutter API to receive callbacks from native
    FastBarcodeScannerFlutterApi.setUp(this);
  }

  @override
  Future<PreviewConfiguration> init(
    List<BarcodeType> types,
    Resolution resolution,
    Framerate framerate,
    DetectionMode detectionMode,
    CameraPosition position, {
    IOSApiMode? apiMode,
    bool enableOcr = false,
    double? confidence,
  }) async {
    final configuration = ScannerConfiguration(
      types: types,
      mode: detectionMode,
      resolution: resolution,
      framerate: framerate,
      position: position,
      apiMode: apiMode,
      enableOcr: enableOcr,
      confidence: confidence,
    );

    return await _hostApi.initialize(configuration);
  }

  @override
  Future<void> start() async {
    await _hostApi.start();
  }

  @override
  Future<void> stop() async {
    await _hostApi.stop();
  }

  @override
  Future<void> startDetector() async {
    await _hostApi.startDetector();
  }

  @override
  Future<void> stopDetector() async {
    await _hostApi.stopDetector();
  }

  @override
  Future<void> dispose() async {
    await _hostApi.dispose();
  }

  @override
  Future<bool> toggleTorch() async {
    return await _hostApi.toggleTorch();
  }

  @override
  Future<PreviewConfiguration> changeConfiguration({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
    bool? enableOcr,
  }) async {
    final configuration = UpdateConfiguration(
      types: types,
      mode: detectionMode,
      resolution: resolution,
      framerate: framerate,
      position: position,
      enableOcr: enableOcr,
    );

    return await _hostApi.changeConfiguration(configuration);
  }

  @override
  void setOnScannedItemDetectedHandler(OnScanDetectedHandler handler) {
    _onScanDetectedHandler = handler;
  }

  @override
  Future<List<ScannedItem>?> scanImage(ImageSourceData source) async {
    final result = await _hostApi.scanImage(source);
    return _scannedDataToScannedItem(result);
  }

  @override
  Future<String?> retrieveCachedImage({required String code}) async {
    return await _hostApi.retrieveCachedImage(code);
  }

  @override
  Future<void> clearCachedImage() async {
    await _hostApi.clearCachedImage();
  }

  List<ScannedItem> _scannedDataToScannedItem(ScanData scanData) {
    final validBarcodes = scanData.barcodes?.whereType<BarcodeData>().map(
              (e) => ScannedBarcode(e),
            ) ??
        [];
    final validOcr = scanData.ocrData?.whereType<OCRData>().map(
              (e) => ScannedOcr(e),
            ) ??
        [];
    return [...validBarcodes, ...validOcr];
  }

  // FastBarcodeScannerFlutterApi implementation
  @override
  void onScanDataDetected(ScanData scanData) {
    if (_onScanDetectedHandler != null) {
      final scannedItems = _scannedDataToScannedItem(scanData);
      if (scannedItems.isNotEmpty) {
        _onScanDetectedHandler!(scannedItems);
      }
    }
  }

  @override
  void onError(String errorCode, String errorMessage, String? errorDetails) {
    debugPrint('Barcode scanner error: $errorCode - $errorMessage');
    if (errorDetails != null) {
      debugPrint('Error details: $errorDetails');
    }
  }
}
