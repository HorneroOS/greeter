#!/bin/sh
# QML lint/format gate for the HorneroOS greeter (Qt6).
# Strategy:
#   - qmllint must pass on every QML file (Qt6 imports, no legacy APIs).
#   - qmlformat --check: files must already be formatted; run this script
#     with FORMAT=1 to rewrite them in place instead of only checking.
#   - pytest tests/ runs the catalog/offline/theme/permission/JS suites.
set -eu

ROOT=$(dirname "$(dirname "$0")")
QML_FILES=$(find "$ROOT" -maxdepth 1 -name '*.qml' -o -path "$ROOT/components/*.qml" | sort)
QML_IMPORT=""
for cand in /usr/lib/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/qml; do
  if [ -d "$cand" ]; then QML_IMPORT="$cand"; break; fi
done

fail=0
# shellcheck disable=SC2086
for f in $QML_FILES; do
  if [ -n "$QML_IMPORT" ]; then
    qmllint -I "$QML_IMPORT" "$f" || fail=1
  else
    qmllint "$f" || fail=1
  fi
done

if [ "${FORMAT:-0}" = "1" ]; then
  # shellcheck disable=SC2086
  qmlformat -i $QML_FILES
else
  for f in $QML_FILES; do
    # qmlformat has no dry-run flag: diff the formatted output instead.
    if ! qmlformat "$f" | cmp -s -- "$f" -; then
      echo "qmlformat: $f is not formatted (run FORMAT=1 $0 to fix)"
      fail=1
    fi
  done
fi

exit $fail
