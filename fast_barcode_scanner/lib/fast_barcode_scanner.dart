export 'package:fast_barcode_scanner/src/barcode_camera.dart';
export 'package:fast_barcode_scanner/src/camera_controller.dart';
export 'package:fast_barcode_scanner/src/overlays/blur_overlay.dart';
export 'package:fast_barcode_scanner/src/overlays/material_finder_overlay/material_finder_overlay.dart';
export 'package:fast_barcode_scanner/src/types/scanner_configuration.dart';
export 'package:fast_barcode_scanner/src/types/scanner_event.dart';

// Export our model classes for backward compatibility
export 'package:fast_barcode_scanner/src/models/barcode.dart';
export 'package:fast_barcode_scanner/src/models/image_source.dart';

// Export Pigeon generated types
export 'package:fast_barcode_scanner/src/generated/scanner_platform_interface.g.dart'
    show
        BarcodeType,
        BarcodeValueType,
        Framerate,
        Resolution,
        DetectionMode,
        CameraPosition,
        PreviewConfiguration,
        Point,
        ApiModeConfig,
        BarcodeData,
        ImageData;

// Export the OnDetectionHandler typedef for use in the public API
export 'package:fast_barcode_scanner/src/camera_controller.dart' show OnDetectionHandler;

export 'src/overlays/code_boundary_overlay/code_boundary_overlay.dart';
export 'src/overlays/overlays.dart';
export 'src/overlays/rect_of_interest/rect_of_interest.dart';
