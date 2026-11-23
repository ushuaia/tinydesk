import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' hide TerminalController;

import '../../session/terminal_controller.dart';
import 'terminal_keys_bar.dart';

class TerminalViewHost extends StatelessWidget {
  const TerminalViewHost({
    super.key,
    required this.controller,
    this.banner,
  });

  final TerminalController controller;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: TerminalView(
            controller.terminal,
            focusNode: controller.focusNode,
            deleteDetection: true,
            keyboardType: TextInputType.emailAddress,
            textStyle: const TerminalStyle(
              fontFamily: 'MesloLGS',
              fontSize: 14,
              height: 1.2,
            ),
            padding: const EdgeInsets.all(4),
          ),
        ),
        ?banner,
        TerminalKeysBar(controller: controller),
      ],
    );
  }
}
