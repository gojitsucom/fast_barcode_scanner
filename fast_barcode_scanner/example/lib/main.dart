import 'dart:io';

import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'scanning_screen/scanning_screen.dart';

void main() {
  runApp(const MaterialApp(home: HomeScreen()));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _disposeCheckboxValue = true;
  String? currentCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fast Barcode Scanner')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              child: const Text('Open Scanner'),
              onPressed: () async {
                IOSApiMode? apiMode;
                if (Platform.isIOS) {
                  apiMode = await showDialog<IOSApiMode>(
                          context: context,
                          builder: (context) => AlertDialog(
                                title: const Text("Scanning Framework"),
                                actions: [
                                  TextButton(
                                      onPressed: () {
                                        Navigator.pop(
                                            context, IOSApiMode.avFoundation);
                                      },
                                      child: const Text("AVFoundation")),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(
                                          context, IOSApiMode.visionStandard);
                                    },
                                    child: const Text("Vision"),
                                  ),
                                ],
                              )) ??
                      IOSApiMode.avFoundation;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanningScreen(
                      dispose: _disposeCheckboxValue,
                      apiMode: apiMode,
                    ),
                  ),
                );
              },
            ),
            ElevatedButton(
              onPressed: () async {
                final cam = CameraController();

                if (currentCode != null) {
                  final imagePath =
                      (await cam.retrieveCachedImage(currentCode!));
                  if (imagePath != null &&
                      context.mounted &&
                      File(imagePath).existsSync()) {
                    showModalBottomSheet(
                        context: context,
                        builder: (context) => Image.file(File(imagePath)));
                  }
                }
              },
              child: const Text('Get Image Cache'),
            ),
            ElevatedButton(
              onPressed: () {
                currentCode = null;
                CameraController().clearCachedImage();
              },
              child: const Text('Clear Image Cache'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Dispose:'),
                Checkbox(
                  value: _disposeCheckboxValue,
                  onChanged: (newValue) => setState(
                    () => _disposeCheckboxValue = newValue!,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
