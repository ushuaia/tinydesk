import 'dart:typed_data';
import '../../core/app_language.dart';

import 'package:flutter/material.dart';


import '../../data/remote_file.dart';
import '../../ssh/tunnel_session.dart';

class ImageReaderPage extends StatefulWidget {
  const ImageReaderPage({
    super.key,
    required this.session,
    required this.file,
    this.embedded = false,
  });

  final TunnelSession session;
  final RemoteFile file;
  final bool embedded;

  @override
  State<ImageReaderPage> createState() => _ImageReaderPageState();
}

class _ImageReaderPageState extends State<ImageReaderPage> {
  late Future<Uint8List> _content;

  @override
  void initState() {
    super.initState();
    _content = widget.session.readBytes(widget.file.path);
  }

  Widget _buildContent() {
    return FutureBuilder<Uint8List>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(AppL10n.t.loadFailed(snapshot.error.toString())));
        }
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildContent();
    return Scaffold(
      appBar: AppBar(title: Text(widget.file.name)),
      body: _buildContent(),
    );
  }
}
