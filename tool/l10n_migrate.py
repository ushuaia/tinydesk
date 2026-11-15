#!/usr/bin/env python3
"""One-shot l10n migration: rewrites Chinese string literals to AppL10n
calls and emits the corresponding ARB entries.

Usage: python3 tool/l10n_migrate.py <batch.json>
Batch JSON: { "files": [...], "entries": { "zh-literal-without-quotes":
  {"key": "...", "en": "...", "expr": "AppL10n.t.hostX(...)", "params": {...}} } }

`expr` is omitted for plain strings (no placeholders). Placeholders use
ARB syntax {name} inside `en`; `expr` must reference the same Dart
expressions as the original interpolation.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARB_EN = ROOT / 'lib/l10n/app_en.arb'
ARB_ZH = ROOT / 'lib/l10n/app_zh.arb'


def load_arb(path):
    return json.loads(path.read_text())


def save_arb(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False))


def main():
    batch = json.loads(Path(sys.argv[1]).read_text())
    files = batch['files']
    entries = batch['entries']

    en = load_arb(ARB_EN)
    zh = load_arb(ARB_ZH)
    added = []

    for zh_literal, spec in entries.items():
        key = spec['key']
        en_text = spec.get('en')
        if key in en:
            pass
        elif en_text is None:
            print(f'SKIP missing en for {key}')
            continue
        else:
            en[key] = en_text
            zh[key] = zh_literal
        meta = spec.get('meta')
        if meta:
            en[f'@{key}'] = meta
        added.append(key)

    for f in files:
        path = ROOT / f
        text = path.read_text()
        original = text
        for zh_literal, spec in entries.items():
            dart_expr = spec.get('expr') or f'AppL10n.t.{spec["key"]}'
            needle = f"'{zh_literal}'"
            if needle in text:
                text = text.replace(needle, dart_expr)
            else:
                dq = f'"{zh_literal}"'
                if dq in text:
                    text = text.replace(dq, dart_expr)
        if text != original:
            # make sure the file can reference the localization holder
            if 'AppL10n' in text and 'app_localizations.dart' not in text:
                rel = path.relative_to(ROOT / 'lib')
                depth = str(rel).count('/')
                prefix = '../' * depth
                t = text
                anchor = re.search(r"^import 'package:flutter/material.dart';$", t, re.M)
                if anchor:
                    t = t[:anchor.end()] + \
                        f"\nimport '{prefix}l10n/gen/app_localizations.dart';" + \
                        t[anchor.end():]
                    text = t
            path.write_text(text)
        print('migrated', f)

    if added:
        save_arb(ARB_EN, en)
        save_arb(ARB_ZH, zh)
        print(f'ARB keys added: {len(added)}')


if __name__ == '__main__':
    main()
