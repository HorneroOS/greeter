#!/bin/sh
# QML lint/format gate for the HorneroOS greeter (Qt6).
# Strategy:
#   - qmllint must pass on every QML file (Qt6 imports, no legacy APIs).
#   - qmlformat --check: files must already be formatted; run this script
#     with FORMAT=1 to rewrite them in place instead of only checking.
#   - pytest tests/ runs the catalog/offline/theme/permission/JS suites.
#
# Tool pinning: distro Qt versions format differently (qmlformat output
# drifts between releases), so this script prefers the version-pinned Qt
# tools from PySide6-Essentials 6.11.* when importable
# (pip install "PySide6-Essentials==6.11.*"; CI installs the same pin).
# Explicit QMLLINT_BIN / QMLFORMAT_BIN env values win over everything;
# otherwise plain PATH tools are the fallback.
set -eu

ROOT=$(dirname "$(dirname "$0")")

PYSIDE_VER=""
if command -v python3 >/dev/null 2>&1; then
  PYSIDE_VER="$(python3 -c 'import PySide6; print(PySide6.__version__)' 2>/dev/null || true)"
fi
if [ -n "${QMLLINT_BIN:-}" ]; then
  QMLLINT="$QMLLINT_BIN"
  QMLFORMAT="${QMLFORMAT_BIN:-qmlformat}"
elif [ "${PYSIDE_VER#6.11.}" != "$PYSIDE_VER" ]; then
  PYSIDE_DIR="$(python3 -c 'import os, PySide6; print(os.path.dirname(PySide6.__file__))')"
  QMLLINT="$PYSIDE_DIR/qmllint"
  QMLFORMAT="$PYSIDE_DIR/qmlformat"
  QML_IMPORT_EXTRA="$PYSIDE_DIR/Qt/qml"
  echo "using pinned Qt tools from PySide6 $PYSIDE_VER"
else
  # Qt6 CLI tools live in /usr/lib/qt6/bin, which is often absent from PATH
  # (e.g. GitHub Actions runners). Pick it up when present so a missing tool
  # fails loudly below instead of producing a bogus "not formatted" report.
  if [ -d /usr/lib/qt6/bin ] && ! command -v qmllint >/dev/null 2>&1; then
    PATH="/usr/lib/qt6/bin:$PATH"
  fi
  QMLLINT="qmllint"
  QMLFORMAT="qmlformat"
  QML_IMPORT_EXTRA=""
fi
command -v "$QMLLINT" >/dev/null 2>&1 || { echo "error: qmllint not found (install qt6-declarative-dev-tools)"; exit 1; }
command -v "$QMLFORMAT" >/dev/null 2>&1 || { echo "error: qmlformat not found (install qt6-declarative-dev-tools)"; exit 1; }
QML_FILES=$(find "$ROOT" -maxdepth 1 -name '*.qml' -o -path "$ROOT/components/*.qml" | sort)
QML_IMPORT=""
# shellcheck disable=SC2086
for cand in ${QML_IMPORT_EXTRA:-} /usr/lib/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/qml; do
  if [ -n "$cand" ] && [ -d "$cand" ]; then
    if [ -z "$QML_IMPORT" ]; then QML_IMPORT="-I $cand"; else QML_IMPORT="$QML_IMPORT -I $cand"; fi
  fi
done

fail=0
# shellcheck disable=SC2086
for f in $QML_FILES; do
  # shellcheck disable=SC2086
  $QMLLINT $QML_IMPORT "$f" || fail=1
done

if [ "${FORMAT:-0}" = "1" ]; then
  # shellcheck disable=SC2086
  $QMLFORMAT -i $QML_FILES
else
  for f in $QML_FILES; do
    # qmlformat has no dry-run flag: diff the formatted output instead.
    if ! $QMLFORMAT "$f" | cmp -s -- "$f" -; then
      echo "qmlformat: $f is not formatted (run FORMAT=1 $0 to fix)"
      $QMLFORMAT "$f" | diff --unified=2 -- "$f" - || true
      fail=1
    fi
  done
fi

exit $fail
