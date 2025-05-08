import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../fast_barcode_scanner.dart';
import 'generated/scanner_platform_interface.g.dart';
import 'models/barcode.dart';
import 'models/image_source.dart';

/// Callback handler method for receiving scanned codes.
typedef OnDetectionHandler = void Function(List<BarcodeData>);

class ScannerState {
  PreviewConfiguration? _previewConfig;
  ScannerConfiguration? _scannerConfig;
  bool _torch = false;
  Object? _error;

  PreviewConfiguration? get previewConfig => _previewConfig;

  ScannerConfiguration? get scannerConfig => _scannerConfig;

  bool get torchState => _torch;

  bool get isInitialized => _previewConfig != null;

  bool get hasError => _error != null;

  Object? get error => _error;
}

/// Middleman, handling the communication with native platforms.
///
/// Allows for custom backends.
abstract class CameraController {
  static final _instance = _CameraController._internal();

  factory CameraController() => _instance;

  /// The cumulated state of the barcode scanner.
  ///
  /// Contains information about the configuration, torch,
  /// and errors
  final state = ScannerState();

  /// reports most recently scanned codes
  ValueNotifier<List<BarcodeData>> get scannedBarcodes;

  /// the size of the image used by the native analysis system to scan the code
  /// scanned codes have coordinate information that is based on this image size
  Size? get analysisSize;

  /// A [ValueNotifier] for camera state events.
  ///
  ///
  final ValueNotifier<ScannerEvent> events =
      ValueNotifier(ScannerEvent.uninitialized);

  /// Informs the platform to initialize the camera.
  ///
  /// Events and errors are received via the current state's eventNotifier.
  Future<void> initialize({
    required List<BarcodeType> types,
    required Resolution resolution,
    required Framerate framerate,
    required CameraPosition position,
    required DetectionMode detectionMode,
    ApiModeConfig? apiMode,
    OnDetectionHandler? onScan,
  });

  /// Stops the camera and disposes all associated resources.
  ///
  ///
  Future<void> dispose();

  /// Resumes the preview on the platform level.
  ///
  ///
  Future<void> resumeCamera();

  /// Pauses the preview on the platform level.
  ///
  ///
  Future<void> pauseCamera();

  /// Resumes the scanner on the platform level.
  ///
  ///
  Future<void> resumeScanner();

  /// Pauses the scanner on the platform level.
  ///
  ///
  Future<void> pauseScanner();

  /// Toggles the torch, if available.
  ///
  ///
  Future<bool> toggleTorch();

  /// Reconfigure the scanner.
  ///
  /// Can be called while running.
  Future<void> configure({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
    OnDetectionHandler? onScan,
  });

  /// Analyze a still image, which can be chosen from an image picker.
  ///
  /// It is recommended to pause the live scanner before calling this.
  Future<List<BarcodeData>?> scanImage(ImageData imageData);

  Future<String?> retrieveCachedImage(String code);

  Future<void> clearCachedImage();
}

/// Implementation of the Flutter API that receives callbacks from the native side.
class BarcodeScannerFlutterApiImpl extends BarcodeScannerFlutterApi {
  final void Function(List<BarcodeData>) onBarcodeDetection;
  final void Function(String) onError;

  BarcodeScannerFlutterApiImpl({
    required this.onBarcodeDetection,
    required this.onError,
  });

  @override
  void onBarcodeDetection(List<BarcodeData> barcodes) {
    this.onBarcodeDetection(barcodes);
  }

  @override
  void onError(String errorMessage) {
    this.onError(errorMessage);
  }
}

class _CameraController implements CameraController {
  _CameraController._internal() : super() {
    _flutterApi = BarcodeScannerFlutterApiImpl(
      onBarcodeDetection: _handleBarcodeDetection,
      onError: _handleError,
    );
    BarcodeScannerFlutterApi.setup(_flutterApi);
  }

  StreamSubscription? _scanSilencerSubscription;

  /// The Pigeon-generated API for communicating with the native side.
  final BarcodeScannerHostApi _api = BarcodeScannerHostApi();

  /// The Flutter API implementation that receives callbacks from the native side.
  late final BarcodeScannerFlutterApiImpl _flutterApi;

  /// Stream controller for barcode detection events.
  final StreamController<List<BarcodeData>> _detectionStreamController =
      StreamController<List<BarcodeData>>.broadcast();

  /// Stream of barcode detection events.
  Stream<List<BarcodeData>> get detectionStream => _detectionStreamController.stream;

  @override
  final state = ScannerState();

  @override
  final events = ValueNotifier(ScannerEvent.uninitialized);

  static const scannedCodeTimeout = Duration(milliseconds: 250);
  DateTime? _lastScanTime;
  @override
  ValueNotifier<List<BarcodeData>> scannedBarcodes = ValueNotifier([]);

  @override
  Size? get analysisSize {
    final previewConfig = state.previewConfig;
    if (previewConfig != null) {
      return Size(previewConfig.analysisWidth.toDouble(),
          previewConfig.analysisHeight.toDouble());
    }
    return null;
  }

  /// Indicates if the torch is currently switching.
  ///
  /// Used to prevent command-spamming.
  bool _togglingTorch = false;

  /// Indicates if the camera is currently configuring itself.
  ///
  /// Used to prevent command-spamming.
  bool _configuring = false;

  /// User-defined handler, called when a barcode is detected
  OnDetectionHandler? _onScan;

  /// Curried function for [_onScan]. This ensures that each scan receipt is done
  /// consistently. We log [_lastScanTime] and update the [scannedBarcodes] ValueNotifier
  OnDetectionHandler _buildScanHandler(OnDetectionHandler? onScan) {
    return (barcodeData) {
      _lastScanTime = DateTime.now();
      scannedBarcodes.value = barcodeData;
      onScan?.call(barcodeData);
    };
  }

  @override
  Future<void> initialize({
    required List<BarcodeType> types,
    required Resolution resolution,
    required Framerate framerate,
    required CameraPosition position,
    required DetectionMode detectionMode,
    ApiModeConfig? apiMode,
    OnDetectionHandler? onScan,
  }) async {
    try {
      // Convert to Pigeon types
      final config = ScannerConfiguration(
        types: types,
        resolution: resolution,
        framerate: framerate,
        detectionMode: detectionMode,
        position: position,
        apiModeConfig: apiMode,
      );

      state._previewConfig = await _api.initialize(config);

      _onScan = _buildScanHandler(onScan);
      _scanSilencerSubscription =
          Stream.periodic(scannedCodeTimeout).listen((event) {
        final scanTime = _lastScanTime;
        if (scanTime != null &&
            DateTime.now().difference(scanTime) > scannedCodeTimeout) {
          // it's been too long since we've seen a scanned code, clear the list
          scannedBarcodes.value = const <BarcodeData>[];
        }
      });

      _onScan = _buildScanHandler(onScan);

      state._scannerConfig = ScannerConfiguration(
          types, resolution, framerate, position, detectionMode);

      state._error = null;

      events.value = ScannerEvent.resumed;
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await clearCachedImage();
      await _api.dispose();
      state._scannerConfig = null;
      state._previewConfig = null;
      state._torch = false;
      state._error = null;
      events.value = ScannerEvent.uninitialized;
      _scanSilencerSubscription?.cancel();
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> pauseCamera() async {
    try {
      await _api.stop();
      events.value = ScannerEvent.paused;
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> resumeCamera() async {
    try {
      await _api.start();
      events.value = ScannerEvent.resumed;
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> pauseScanner() async {
    try {
      await _api.stopDetector();
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> resumeScanner() async {
    try {
      await _api.startDetector();
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<bool> toggleTorch() async {
    if (!_togglingTorch) {
      _togglingTorch = true;

      try {
        state._torch = await _api.toggleTorch();
      } catch (error) {
        state._error = error;
        events.value = ScannerEvent.error;
        rethrow;
      }

      _togglingTorch = false;
    }

    return state._torch;
  }

  @override
  Future<void> configure({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
    OnDetectionHandler? onScan,
  }) async {
    if (state.isInitialized && !_configuring) {
      final scannerConfig = state._scannerConfig!;
      _configuring = true;

      try {
        // Convert to Pigeon types
        final config = ScannerConfiguration(
          types: types ?? [],
          resolution: resolution ?? Resolution.hd720,
          framerate: framerate ?? Framerate.fps30,
          detectionMode: detectionMode ?? DetectionMode.pauseDetection,
          position: position ?? CameraPosition.back,
        );

        state._previewConfig = await _api.updateConfiguration(config);

        state._scannerConfig = scannerConfig.copyWith(
          types: types,
          resolution: resolution,
          framerate: framerate,
          detectionMode: detectionMode,
          position: position,
        );

        _onScan = _buildScanHandler(onScan);
      } catch (error) {
        state._error = error;
        events.value = ScannerEvent.error;
        rethrow;
      }

      _configuring = false;
    }
  }

  @override
  Future<List<BarcodeData>?> scanImage(ImageData imageData) async {
    try {
      return await _api.scanImage(imageData);
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<String?> retrieveCachedImage(String code) async {
    try {
      return (await _api.retrieveCachedImage(code))
          ?.replaceAll("file:///", "");
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  @override
  Future<void> clearCachedImage() async {
    try {
      await _api.clearCachedImage();
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  void _onDetectHandler(List<BarcodeData> codes) {
    events.value = ScannerEvent.detected;
    _onScan?.call(codes);
  }

  void _handleBarcodeDetection(List<BarcodeData> barcodes) {
    _detectionStreamController.add(barcodes);
    _onScan?.call(barcodes);
  }

  void _handleError(String errorMessage) {
    print('Barcode scanner error: $errorMessage');
    state._error = errorMessage;
    events.value = ScannerEvent.error;
  }
}

class ScannedBarcodes {
  final List<BarcodeData> barcodes;
  final DateTime scannedAt;

  ScannedBarcodes(this.barcodes) : scannedAt = DateTime.now();

  ScannedBarcodes.none() : this([]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedBarcodes &&
          runtimeType == other.runtimeType &&
          barcodes == other.barcodes &&
          scannedAt == other.scannedAt;

  @override
  int get hashCode => barcodes.hashCode ^ scannedAt.hashCode;
}
