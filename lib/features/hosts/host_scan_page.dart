import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/app_language.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen QR scanner for Android and iOS that collects several codes in
/// one camera session. The two-stage host transfer needs two codes, and
/// recreating the camera for the second scan crashes mobile_scanner on iOS,
/// so both are scanned without leaving the page.
///
/// Sends the collected codes back through the navigator. HarmonyOS uses the
/// Scan Kit plugin instead and platforms without a camera show the paste
/// fallback.
class HostScanPage extends StatefulWidget {
  const HostScanPage({super.key, this.expected = 1});

  /// How many distinct codes to collect before returning.
  final int expected;

  @override
  State<HostScanPage> createState() => _HostScanPageState();
}

class _HostScanPageState extends State<HostScanPage> {
  final _codes = <String>[];
  MobileScannerController? _controller;
  bool _done = false;

  bool get _hasCamera => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (_hasCamera) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_done) return;
    _done = true;
    // Stop the camera before leaving the route: popping with a running
    // session lets a late platform callback hit a disposed view (black
    // frame / null pointer on iOS).
    try {
      await _controller?.stop();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(List<String>.of(_codes));
  }

  /// Resets the analyzer after a collected code: the plugin keeps the first
  /// result cached, which otherwise prevents the next code from being
  /// reported while the previous one is still in view.
  Future<void> _restartDetection() async {
    try {
      await _controller?.pause();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted || _done) return;
      await _controller?.start();
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    var added = false;
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue;
      if (text == null || text.isEmpty) continue;
      if (_codes.contains(text)) continue;
      _codes.add(text);
      added = true;
      if (_codes.length >= widget.expected) break;
    }
    if (!added) return;
    if (_codes.length >= widget.expected) {
      _finish();
      return;
    }
    setState(() {});
    unawaited(_restartDetection());
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCamera) {
      return Scaffold(
        appBar: AppBar(title: Text(AppL10n.t.scanButton)),
        body: Center(
          child: Text(AppL10n.t.noCameraFallback),
        ),
      );
    }
    final showProgress = widget.expected > 1;
    return Scaffold(
      appBar: AppBar(title: Text(AppL10n.t.scanButton)),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          if (showProgress)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    '${_codes.length}/${widget.expected}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
