import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinydesk/features/documents/floating_file_browser_shell.dart';

class _CountingContent extends StatefulWidget {
  const _CountingContent({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_CountingContent> createState() => _CountingContentState();
}

class _CountingContentState extends State<_CountingContent> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: Key('content'));
}

void main() {
  Widget wrap({
    required bool visible,
    required bool expanded,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    Widget? child,
  }) {
    return MaterialApp(
      home: Stack(
        children: [
          FloatingFileBrowserShell(
            visible: visible,
            expanded: expanded,
            ballOffset: const Offset(100, 100),
            onBallTap: onTap ?? () {},
            onBallLongPress: onLongPress,
            onBallDragUpdate: (_) {},
            onBallDragEnd: () {},
            child: child ?? const SizedBox.expand(key: Key('content')),
          ),
        ],
      ),
    );
  }

  testWidgets('hides everything when not visible', (tester) async {
    await tester.pumpWidget(wrap(visible: false, expanded: false));
    expect(find.byIcon(Icons.folder_open), findsNothing);
    expect(find.byKey(const Key('content')), findsNothing);
  });

  testWidgets('shows only the ball when minimized', (tester) async {
    await tester.pumpWidget(wrap(visible: true, expanded: false));
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    final window = tester.widget<Visibility>(
      find.ancestor(
        of: find.byKey(const Key('content')),
        matching: find.byType(Visibility),
      ).first,
    );
    expect(window.visible, isFalse);
  });

  testWidgets('shows only the window when expanded', (tester) async {
    await tester.pumpWidget(wrap(visible: true, expanded: true));
    expect(find.byIcon(Icons.folder_open), findsNothing);
    expect(find.byKey(const Key('content')), findsOneWidget);
  });

  testWidgets('ball tap and long press reach the callbacks', (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(wrap(
      visible: true,
      expanded: false,
      onTap: () => taps++,
      onLongPress: () => longPresses++,
    ));
    await tester.tap(find.byIcon(Icons.folder_open));
    await tester.longPress(find.byIcon(Icons.folder_open));
    expect(taps, 1);
    expect(longPresses, 1);
  });

  testWidgets('minimizing keeps the window subtree alive', (tester) async {
    var inits = 0;
    final child = _CountingContent(onInit: () => inits++);

    await tester.pumpWidget(wrap(visible: true, expanded: true, child: child));
    expect(inits, 1);

    await tester.pumpWidget(wrap(visible: true, expanded: false, child: child));
    await tester.pump();
    expect(find.byIcon(Icons.folder_open), findsOneWidget);

    await tester.pumpWidget(wrap(visible: true, expanded: true, child: child));
    await tester.pump();
    expect(inits, 1);
  });

  testWidgets('dialogs opened inside the window find a Navigator',
      (tester) async {
    // Mirror app.dart: the shell is a sibling of the MaterialApp Navigator,
    // so the window must bring its own Navigator for dialogs and menus.
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => Stack(
        children: [
          if (child != null) Positioned.fill(child: child),
          FloatingFileBrowserShell(
            visible: true,
            expanded: true,
            ballOffset: const Offset(100, 100),
            onBallTap: () {},
            onBallDragUpdate: (_) {},
            onBallDragEnd: () {},
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(content: Text('dialog')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ],
      ),
      home: const SizedBox.shrink(),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('dialog'), findsOneWidget);
  });
}
