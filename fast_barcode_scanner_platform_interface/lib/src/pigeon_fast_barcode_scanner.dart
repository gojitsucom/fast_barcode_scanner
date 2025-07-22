import 'dart:async';

import 'package:flutter/foundation.dart';

import 'fast_barcode_scanner_platform_interface.dart';
import 'pigeon_barcode_scanner.dart';

/// Implementation of [FastBarcodeScannerPlatform] using Pigeon.
class PigeonFastBarcodeScanner extends FastBarcodeScannerPlatform implements FastBarcodeScannerFlutterApi {
  static final FastBarcodeScannerHostApi _hostApi = FastBarcodeScannerHostApi();
  
  OnDetectionHandler? _onDetectHandler;

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
  }) async {
    final configuration = ScannerConfiguration(
      types: types,
      mode: detectionMode,
      resolution: resolution,
      framerate: framerate,
      position: position,
      apiMode: apiMode,
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
  }) async {
    final configuration = UpdateConfiguration(
      types: types,
      mode: detectionMode,
      resolution: resolution,
      framerate: framerate,
      position: position,
    );

    return await _hostApi.changeConfiguration(configuration);
  }

  @override
  void setOnDetectHandler(OnDetectionHandler handler) {
    _onDetectHandler = handler;
  }

  @override
  Future<List<Barcode>?> scanImage(ImageSourceData source) async {
    final result = await _hostApi.scanImage(source);
    return result.whereType<Barcode>().toList();
  }

  @override
  Future<String?> retrieveCachedImage({required String code}) async {
    return await _hostApi.retrieveCachedImage(code);
  }

  @override
  Future<void> clearCachedImage() async {
    await _hostApi.clearCachedImage();
  }

  // FastBarcodeScannerFlutterApi implementation
  @override
  void onBarcodesDetected(List<Barcode?> barcodes) {
    if (_onDetectHandler != null) {
      final validBarcodes = barcodes.whereType<Barcode>().toList();
      _onDetectHandler!(validBarcodes);
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
