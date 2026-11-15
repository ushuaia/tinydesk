import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/app_language.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen QR scanner for Android and iOS. Returns the scanned text
/// through the navigator; HarmonyOS uses the Scan Kit plugin instead and
/// platforms without a camera show the paste fallback.
class HostScanPage extends StatelessWidget {
  const HostScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(title: Text(AppL10n.t.scanButton)),
        body: Center(
          child: Text(AppL10n.t.noCameraFallback),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(AppL10n.t.scanButton)),
      body: MobileScanner(
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final text = barcode.rawValue;
            if (text != null && text.isNotEmpty) {
              Navigator.of(context).pop(text);
              return;
            }
          }
        },
      ),
    );
  }
}
