import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/data/shell_session.dart';
import 'package:tinydesk/data/remote_file.dart';
import 'package:tinydesk/features/documents/document_editor_support.dart';
import 'package:tinydesk/opencode/opencode_client.dart';
import 'package:tinydesk/ssh/tunnel_session.dart';

class _FakeSession implements TunnelSession {
  _FakeSession({Uint8List? bytes, this.listing = const [], this.failListing = false})
      : bytes = bytes ?? Uint8List(0);

  Uint8List bytes;
  List<RemoteFile> listing;
  bool failListing;

  @override
  Future<Uint8List> readBytes(String path) async => bytes;

  @override
  Future<String> readText(String path) async => '';

  @override
  Future<List<RemoteFile>> listDirectory(String path) async {
    if (failListing) throw const FileSystemException('connection reset');
    return listing;
  }

  @override
  Future<String> runCommand(String command) async => '';

  @override
  Future<void> delete(String path) async {}

  @override
  Future<void> writeText(String path, String content) async {}

  @override
  Future<ServerStatus> probe(String baseUrl) async => ServerStatus.online;

  @override
  Future<String> createPairLink(String localBaseUrl) {
    throw UnimplementedError();
  }

  @override
  Future<void> startService() async {}

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> downloadFile(String remotePath, File destination) async {}

  @override
  Future<DateTime?> statModified(String path) async => null;

  @override
  Future<String> homeDirectory() async => '/home/test';

  @override
  Future<ShellSession> openShell({int width = 80, int height = 24}) {
    throw UnimplementedError();
  }

  @override
  Future<void> keepAlive() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> get closed => Completer<void>().future;
}

RemoteFile _file({int? size, DateTime? modifiedAt}) => RemoteFile(
      name: 'a.txt',
      path: '/tmp/a.txt',
      isDirectory: false,
      size: size,
      modifiedAt: modifiedAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('utf8 text is editable', () async {
    final session = _FakeSession(
      bytes: Uint8List.fromList(utf8.encode('hello 世界')),
    );
    final doc = await DocumentEditorSupport.load(session, _file());
    expect(doc.text, 'hello 世界');
    expect(doc.editable, isTrue);
    expect(doc.readOnlyReason, isNull);
  });

  test('binary content is read-only', () async {
    final session = _FakeSession(
      bytes: Uint8List.fromList([1, 2, 0, 4]),
    );
    final doc = await DocumentEditorSupport.load(session, _file());
    expect(doc.editable, isFalse);
    expect(doc.readOnlyReason, contains('Binary'));
  });

  test('files over 2MB are read-only, over 5MB are rejected', () async {
    final big = _FakeSession(
      bytes: Uint8List.fromList(
        List<int>.filled(DocumentEditorSupport.maxEditableBytes + 1, 0x41),
      ),
    );
    final doc = await DocumentEditorSupport.load(big, _file());
    expect(doc.editable, isFalse);
    expect(doc.readOnlyReason, contains('2MB'));

    final huge = _FakeSession(
      bytes: Uint8List.fromList(
        List<int>.filled(DocumentEditorSupport.maxReadableBytes + 1, 0x41),
      ),
    );
    expect(
      () => DocumentEditorSupport.load(huge, _file()),
      throwsA(isA<FormatException>()),
    );
  });

  test('changedOnRemote detects newer mtime and size changes', () async {
    final opened = _file(
      size: 10,
      modifiedAt: DateTime(2026, 1, 1),
    );
    final same = _FakeSession(
      listing: [
        _file(size: 10, modifiedAt: DateTime(2026, 1, 1)),
      ],
    );
    expect(
      await DocumentEditorSupport.changedOnRemote(same, opened),
      isFalse,
    );

    final newer = _FakeSession(
      listing: [
        _file(size: 10, modifiedAt: DateTime(2026, 1, 2)),
      ],
    );
    expect(
      await DocumentEditorSupport.changedOnRemote(newer, opened),
      isTrue,
    );

    final resized = _FakeSession(
      listing: [
        _file(size: 11, modifiedAt: DateTime(2026, 1, 1)),
      ],
    );
    expect(
      await DocumentEditorSupport.changedOnRemote(resized, opened),
      isTrue,
    );
  });

  test('changedOnRemote reports an unverifiable state instead of guessing',
      () async {
    final broken = _FakeSession(failListing: true);

    await expectLater(
      DocumentEditorSupport.changedOnRemote(broken, _file()),
      throwsA(isA<FileSystemException>()),
    );
  });
}
