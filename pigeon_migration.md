# Migration Guide: Method Channel to Pigeon

This document outlines the complete migration process from Flutter Method Channels to Pigeon for the Fast Barcode Scanner plugin.

## Overview

This migration improves type safety, reduces boilerplate code, and provides better error handling by replacing manual method channel implementations with Pigeon-generated code.

## 🔄 Migration Steps

### 1. Define Pigeon API Schema

**File:** `fast_barcode_scanner_platform_interface/pigeons/barcode_api.dart`

```dart
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/pigeon_barcode_scanner.dart',
  kotlinOut: '../fast_barcode_scanner/android/src/main/kotlin/com/jhoogstraat/fast_barcode_scanner/pigeon/BarcodeApi.kt',
  swiftOut: '../fast_barcode_scanner/ios/Classes/pigeon/BarcodeApi.swift',
  kotlinOptions: KotlinOptions(package: 'com.jhoogstraat.fast_barcode_scanner.pigeon'),
))

/// Data classes
class PointData {
  PointData({required this.x, required this.y});
  final int x;     
  final int y;    
}

class PreviewConfiguration {
  PreviewConfiguration({
    required this.textureId,
    required this.targetRotation,
    required this.height,        // Kept as double
    required this.width,         // Kept as double
    required this.analysisWidth, // Kept as double
    required this.analysisHeight, // Kept as double
  });
  
  final int textureId;
  final int targetRotation;
  final double height;
  final double width;
  final double analysisWidth;
  final double analysisHeight;
}

/// Host API (Dart -> Native)
@HostApi()
abstract class FastBarcodeScannerHostApi {
  @async
  PreviewConfiguration initialize(ScannerConfiguration configuration);
  
  @async
  void start();
  
  @async
  void stop();
  
  // ... other methods
}

/// Flutter API (Native -> Dart)
@FlutterApi()
abstract class FastBarcodeScannerFlutterApi {
  void onBarcodesDetected(List<BarcodeData?> barcodes);
  void onError(String errorCode, String errorMessage, String? errorDetails);
}
```

### 2. Generate Pigeon Code

```bash
cd fast_barcode_scanner_platform_interface
fvm dart run pigeon --input pigeons/barcode_api.dart
```

This generates:
- `lib/src/pigeon_barcode_scanner.dart` (Dart)
- `../fast_barcode_scanner/android/.../BarcodeApi.kt` (Android)
- `../fast_barcode_scanner/ios/Classes/pigeon/BarcodeApi.swift` (iOS)

### 3. Implement Platform Interface

**File:** `fast_barcode_scanner_platform_interface/lib/src/pigeon_fast_barcode_scanner.dart`

```dart
class PigeonFastBarcodeScanner extends FastBarcodeScannerPlatform 
    implements FastBarcodeScannerFlutterApi {
  
  static final FastBarcodeScannerHostApi _hostApi = FastBarcodeScannerHostApi();
  OnDetectionHandler? _onDetectHandler;

  PigeonFastBarcodeScanner() {
    FastBarcodeScannerFlutterApi.setUp(this);
  }

  // Host API implementations
  @override
  Future<PreviewConfiguration> initialize(ScannerConfiguration config) async {
    return await _hostApi.initialize(config);
  }

  // Flutter API implementations
  @override
  void onBarcodesDetected(List<BarcodeData?> barcodes) {
    if (_onDetectHandler != null) {
      final validBarcodes = barcodes.whereType<BarcodeData>().toList();
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
```

### 4. Update Android Implementation

**File:** `fast_barcode_scanner/android/src/main/kotlin/com/jhoogstraat/fast_barcode_scanner/FastBarcodeScannerPlugin.kt`

**Before (Method Channel):**
```kotlin
class FastBarcodeScannerPlugin : FlutterPlugin, MethodCallHandler {
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initialize" -> {
        // Manual parameter parsing
        val config = call.arguments as Map<String, Any>
        // Manual result handling
        result.success(previewConfig)
      }
    }
  }
}
```

**After (Pigeon):**
```kotlin
class FastBarcodeScannerPlugin : FlutterPlugin, FastBarcodeScannerHostApi {
  
  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    FastBarcodeScannerHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    flutterApi = FastBarcodeScannerFlutterApi(flutterPluginBinding.binaryMessenger)
  }

  override fun initialize(
    configuration: ScannerConfiguration, 
    callback: (Result<PreviewConfiguration>) -> Unit
  ) {
    try {
      val previewConfig = initializeCamera(configuration)
      callback(Result.success(previewConfig))
    } catch (e: Exception) {
      e.asFlutterResult(callback)
    }
  }
}
```

### 5. Update iOS Implementation

**File:** `fast_barcode_scanner/ios/Classes/FastBarcodeScannerPlugin.swift`

**Before (Method Channel):**
```swift
public class FastBarcodeScannerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "fast_barcode_scanner", binaryMessenger: registrar.messenger())
    let instance = FastBarcodeScannerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      // Manual parameter parsing and result handling
    }
  }
}
```

**After (Pigeon):**
```swift
public class FastBarcodeScannerPlugin: NSObject, FlutterPlugin, FastBarcodeScannerHostApi {
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let api = FastBarcodeScannerPlugin()
    FastBarcodeScannerHostApiSetup.setUp(binaryMessenger: messenger, api: api)
    api.flutterApi = FastBarcodeScannerFlutterApi(binaryMessenger: messenger)
  }

  func initialize(
    configuration: ScannerConfiguration, 
    completion: @escaping (Result<PreviewConfiguration, Error>) -> Void
  ) {
    do {
      let previewConfig = try initializeCamera(configuration: configuration)
      completion(.success(previewConfig))
    } catch {
      completion(.failure(error))
    }
  }
}
```

### 6. Update Extensions for Type Changes

**File:** `fast_barcode_scanner_platform_interface/lib/src/pigeon_extensions_full.dart`

```dart
extension PointDataExtension on PointData {
  /// Convert to Flutter Offset (int -> double conversion)
  Offset toOffset() => Offset(x.toDouble(), y.toDouble());
  
  /// Calculate distance to another point
  double distanceTo(PointData other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return dart_math.sqrt((dx * dx + dy * dy).toDouble());
  }
  
  /// Create copy with new values
  PointData copyWith({int? x, int? y}) {
    return PointData(
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}
```

### 7. Update Native Extensions

**Android:** `fast_barcode_scanner/android/src/main/kotlin/com/jhoogstraat/fast_barcode_scanner/PigeonExtensions.kt`

```kotlin
// Convert coordinates to Long (int equivalent)
val cornerPoints = this.cornerPoints?.map { point ->
    PointData(x = point.x.toLong(), y = point.y.toLong())
}
```

**iOS:** `fast_barcode_scanner/ios/Classes/PigeonExtensions.swift`

```swift
// Convert coordinates to Int64 (int equivalent)
cornerPoints = pointList.map { point in
    guard point.count >= 2 else { return nil }
    return PointData(x: Int64(point[0]), y: Int64(point[1]))
}
```

## 🎯 Benefits of Migration

### 1. **Type Safety**
- Compile-time type checking
- No more manual casting
- Reduced runtime errors

### 2. **Reduced Boilerplate**
- Auto-generated serialization
- Consistent error handling
- No manual method channel setup

### 3. **Better Error Handling**
- Structured error callbacks
- Consistent error format across platforms
- Proper async error propagation

### 4. **Maintainability**
- Single source of truth (Pigeon schema)
- Automatic code generation
- Consistent APIs across platforms

### 5. **Performance**
- Optimized serialization
- Reduced method call overhead
- Better memory management

## 🔧 Key Changes Summary

| Aspect | Before (Method Channel) | After (Pigeon) |
|--------|------------------------|----------------|
| **Type Safety** | Runtime casting | Compile-time types |
| **Error Handling** | Manual error codes | Structured callbacks |
| **Code Generation** | Manual implementation | Auto-generated |
| **Serialization** | Manual JSON handling | Auto-generated codecs |

### Key Learnings
- Threading wrappers can interfere with AVFoundation coordinate transformations
- Portrait mode requires explicit dimension swapping for camera formats
- Consistency between platforms is crucial for accurate point positioning
