#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <text-file> [<text-file> ...]" >&2
  exit 1
fi

for src in "$@"; do
  if [ ! -f "$src" ]; then
    echo "Missing file: $src" >&2
    exit 1
  fi

  case "$src" in
    *.txt) dst="${src%.txt}.cleaned.txt" ;;
    *) dst="${src}.cleaned.txt" ;;
  esac

  perl -CSDA -0pe '
    s/\r\n?/\n/g;
    s/\f/\n\n--- Page Break ---\n\n/g;
    s/[ \t\x{00a0}]+/ /g;
    s/^[ \t]+|[ \t]+$//mg;
    s/\n[ \t]+/\n/g;
    s/\n{3,}/\n\n/g;
    s/\A\s+|\s+\z//g;
    $_ .= "\n" unless /\n\z/;
  ' "$src" > "$dst"

  echo "$dst"
done
