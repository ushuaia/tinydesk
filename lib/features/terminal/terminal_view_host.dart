import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' hide TerminalController;
import 'package:xterm/xterm.dart' as xterm show TerminalController;

import '../../core/app_language.dart';
import '../../data/app_settings.dart';
import '../../session/terminal_controller.dart';
import 'terminal_keys_bar.dart';

class TerminalViewHost extends StatefulWidget {
  const TerminalViewHost({
    super.key,
    required this.controller,
    this.banner,
  });

  final TerminalController controller;
  final Widget? banner;

  @override
  State<TerminalViewHost> createState() => _TerminalViewHostState();
}

class _TerminalViewHostState extends State<TerminalViewHost> {
  final xterm.TerminalController _xterm = xterm.TerminalController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey<TerminalViewState> _terminalKey =
      GlobalKey<TerminalViewState>();
  Offset? _dragStart;
  DateTime? _lastTapAt;
  Offset? _lastTapPos;
  final TextEditingController _searchText = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _searchOpen = false;
  List<int> _matchLines = const [];
  int _matchIndex = 0;

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows;

  @override
  void dispose() {
    _xterm.dispose();
    _scroll.dispose();
    _searchText.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- clipboard

  Future<void> _copySelection() async {
    final selection = _xterm.selection;
    if (selection == null) {
      debugPrint('term: copy skipped (no selection)');
      return;
    }
    final text = widget.controller.terminal.buffer.getText(selection);
    debugPrint('term: copy ${text.length} chars');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    widget.controller.sendText(text);
  }

  /// Builds the selection anchor for a cell; the line owns the anchor so it
  /// survives scrolling until the selection is replaced.
  CellAnchor _anchorAt(CellOffset cell) =>
      widget.controller.terminal.buffer.createAnchorFromOffset(cell);

  void _onPointerDown(PointerDownEvent event) {
    if (!_isDesktop) return;
    debugPrint('term: down buttons=${event.buttons}');
    if (event.buttons != kPrimaryMouseButton) return;
    _dragStart = event.position;
    _xterm.clearSelection();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _dragStart;
    if (start == null) return;
    final render = _terminalKey.currentState?.renderTerminal;
    if (render == null) {
      debugPrint('term: drag, render=null');
      return;
    }
    final base = render.getCellOffset(render.globalToLocal(start));
    final extent = render.getCellOffset(render.globalToLocal(event.position));
    _xterm.setSelection(
      _anchorAt(base),
      _anchorAt(extent),
      mode: SelectionMode.line,
    );
    debugPrint('term: select base=${base.x},${base.y} '
        'extent=${extent.x},${extent.y} '
        'active=${_xterm.selection != null}');
  }

  void _onPointerUp(PointerUpEvent event) {
    final start = _dragStart;
    _dragStart = null;
    if (start == null) return;

    final now = DateTime.now();
    final moved = (start - event.position).distance;
    final last = _lastTapAt;
    final lastPos = _lastTapPos;
    final isDoubleTap = last != null &&
        lastPos != null &&
        now.difference(last) < const Duration(milliseconds: 320) &&
        (lastPos - event.position).distance < 8 &&
        moved < 8;
    _lastTapAt = now;
    _lastTapPos = event.position;

    if (isDoubleTap) {
      // Double click selects the word under the pointer.
      final render = _terminalKey.currentState?.renderTerminal;
      render?.selectWord(render.globalToLocal(event.position));
      if (_xterm.selection != null) unawaited(_copySelection());
      return;
    }

    // Select-to-copy: as soon as a drag produced a selection, the text is
    // on the clipboard.
    if (_xterm.selection != null) {
      unawaited(_copySelection());
    }
  }

  // ------------------------------------------------------------------ search

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _matchLines = const [];
        _matchIndex = 0;
        _searchText.clear();
      }
    });
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  void _runSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _matchLines = const [];
        _matchIndex = 0;
      });
      return;
    }
    final buffer = widget.controller.terminal.buffer;
    final lines = buffer.getText().split('\n');
    final needle = query.toLowerCase();
    final matches = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().contains(needle)) matches.add(i);
    }
    setState(() {
      _matchLines = matches;
      _matchIndex = 0;
    });
    _jumpToMatch(0);
  }

  void _stepMatch(int delta) {
    if (_matchLines.isEmpty) return;
    final next = (_matchIndex + delta) % _matchLines.length;
    setState(() => _matchIndex = next);
    _jumpToMatch(next);
  }

  /// Scrolls the terminal so the matching line is visible. The buffer has no
  /// per-line pixel API, so we map the line index onto the scroll extent.
  void _jumpToMatch(int index) {
    if (_matchLines.isEmpty || !_scroll.hasClients) return;
    final line = _matchLines[index.clamp(0, _matchLines.length - 1)];
    final total = widget.controller.terminal.buffer.height;
    final max = _scroll.position.maxScrollExtent;
    if (total <= 1 || max <= 0) return;
    final ratio = (line / (total - 1)).clamp(0.0, 1.0);
    unawaited(_scroll.animateTo(
      ratio * max,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    ));
  }

  // -------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
            () => unawaited(_copySelection()),
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            () => unawaited(_paste()),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.equal, meta: true):
            () => unawaited(widget.controller.adjustFontSize(1)),
        const SingleActivator(LogicalKeyboardKey.minus, meta: true):
            () => unawaited(widget.controller.adjustFontSize(-1)),
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
            () => unawaited(widget.controller
                .setFontSize(AppSettings.terminalFontSizeDefault)),
      },
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  child: TerminalView(
                  key: _terminalKey,
                  widget.controller.terminal,
                  controller: _xterm,
                  scrollController: _scroll,
                  focusNode: widget.controller.focusNode,
                  deleteDetection: true,
                  keyboardType: TextInputType.emailAddress,
                  cursorType: TerminalCursorType.verticalBar,
                  textStyle: TerminalStyle(
                    fontFamily: 'MesloLGS',
                    fontSize: widget.controller.fontSize.toDouble(),
                    height: 1.2,
                  ),
                  padding: const EdgeInsets.all(4),
                  ),
                ),
                if (_searchOpen) _searchBar(context),
              ],
            ),
          ),
          ?widget.banner,
          if (!_isDesktop)
            TerminalKeysBar(
              controller: widget.controller,
              onPaste: () => unawaited(_paste()),
            ),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _matchLines.length;
    final position = total == 0 ? 0 : _matchIndex + 1;
    return Positioned(
      top: 6,
      right: 6,
      left: 40,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchText,
                  focusNode: _searchFocus,
                  onChanged: _runSearch,
                  onSubmitted: (_) => _stepMatch(1),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: AppL10n.t.terminalSearchHint,
                  ),
                ),
              ),
              Text('$position/$total',
                  style: Theme.of(context).textTheme.labelSmall),
              IconButton(
                iconSize: 18,
                onPressed: () => _stepMatch(-1),
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                iconSize: 18,
                onPressed: () => _stepMatch(1),
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                iconSize: 18,
                onPressed: _toggleSearch,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
