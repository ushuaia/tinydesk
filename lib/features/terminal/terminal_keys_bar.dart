import 'package:flutter/material.dart';

import 'terminal_controller.dart';

class TerminalKeysBar extends StatelessWidget {
  const TerminalKeysBar({super.key, required this.controller});

  final TerminalController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1E1E1E),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 6, right: 24),
          children: [
            _KeyButton(
              label: 'Esc',
              onTap: () => controller.sendKey('\x1b'),
            ),
            _KeyButton(
              label: 'Tab',
              onTap: () => controller.sendKey('\t'),
            ),
            _KeyButton(
              label: 'Ctrl',
              active: controller.ctrl,
              onTap: controller.toggleCtrl,
            ),
            _KeyButton(
              label: 'Alt',
              active: controller.alt,
              onTap: controller.toggleAlt,
            ),
            _KeyButton(
              label: '←',
              onTap: () => controller.sendKey('\x1b[D'),
            ),
            _KeyButton(
              label: '↑',
              onTap: () => controller.sendKey('\x1b[A'),
            ),
            _KeyButton(
              label: '↓',
              onTap: () => controller.sendKey('\x1b[B'),
            ),
            _KeyButton(
              label: '→',
              onTap: () => controller.sendKey('\x1b[C'),
            ),
            _KeyButton(
              label: 'Home',
              onTap: () => controller.sendKey('\x1b[H'),
            ),
            _KeyButton(
              label: 'End',
              onTap: () => controller.sendKey('\x1b[F'),
            ),
            _KeyButton(
              label: 'PgUp',
              onTap: () => controller.sendKey('\x1b[5~'),
            ),
            _KeyButton(
              label: 'PgDn',
              onTap: () => controller.sendKey('\x1b[6~'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      child: Material(
        color: active ? const Color(0xFF3B6EA8) : const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
