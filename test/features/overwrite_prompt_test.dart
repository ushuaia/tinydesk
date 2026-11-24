import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/features/documents/document_editor_support.dart';

class _Pending {
  bool? result;
  bool opened = false;
}

Future<_Pending> _show(WidgetTester tester) async {
  final pending = _Pending();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            if (pending.opened) return;
            pending.opened = true;
            pending.result =
                await DocumentEditorSupport.confirmOverwrite(context);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return pending;
}

void main() {
  testWidgets('confirming overwrites', (tester) async {
    final pending = await _show(tester);
    await tester.tap(find.text('Overwrite'));
    await tester.pumpAndSettle();

    expect(pending.result, isTrue);
  });

  testWidgets('cancelling keeps the edit unsaved', (tester) async {
    final pending = await _show(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(pending.result, isFalse);
  });
}
