# xterm (vendored)

Source: https://github.com/TerminalStudio/xterm.dart, version 4.0.0, MIT license.

Only `lib/`, `pubspec.yaml`, and `LICENSE` are vendored.

Local patch:

- `lib/src/ui/shortcut/shortcuts.dart`: the `switch` over `defaultTargetPlatform`
  is not exhaustive on Flutter for OpenHarmony because the fork adds
  `TargetPlatform.ohos`. Added a `default` branch so the package compiles for
  HarmonyOS NEXT. Upstream Flutter's behavior is unchanged.

Re-vendoring: copy a new release into this directory and re-apply the patch.
