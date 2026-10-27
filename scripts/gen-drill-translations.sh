#!/usr/bin/env bash
# Generates DrillLocalizations from the ARB files of lib/l10n/drill, the UI text of Drills.
#
# `flutter gen-l10n` only reads the l10n.yaml of the directory it runs in, which holds the config
# of AppLocalizations, so it runs here in a temporary project with the config of Drills.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
L10N_DIR="$ROOT_DIR/lib/l10n/drill"

# The temporary project is outside the repo, where fvm can't find the Flutter version it uses.
if [[ -x "$ROOT_DIR/.fvm/flutter_sdk/bin/flutter" ]]; then
  FLUTTER="$ROOT_DIR/.fvm/flutter_sdk/bin/flutter"
else
  FLUTTER=flutter
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/pubspec.yaml" <<YAML
name: drill_l10n
flutter:
  generate: true
YAML

cat > "$TMP_DIR/l10n.yaml" <<YAML
arb-dir: $L10N_DIR
output-dir: $L10N_DIR
template-arb-file: drill_en.arb
output-localization-file: drill_localizations.dart
output-class: DrillLocalizations
preferred-supported-locales: [en]
nullable-getter: false
format: false
YAML

(cd "$TMP_DIR" && "$FLUTTER" gen-l10n)
