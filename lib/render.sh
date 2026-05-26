#!/usr/bin/env bash
# render.sh - substitute @@TOKEN@@ placeholders from a values file.
#
# Values file: `KEY=value` lines; blank lines and `#` comments ignored. A token
# `@@KEY@@` anywhere in the input is replaced by the matching value. Tokens are
# `@@`-delimited so no key can be a prefix of another at the match boundary, and
# the substitution is a single sed pass (order-independent).
#
# Usage:
#   render.sh VALUES < input > output     # filter mode (stdin -> stdout)
#   render.sh VALUES FILE                 # render FILE to stdout
set -euo pipefail

values="${1:?usage: render.sh VALUES [FILE]}"
shift || true
[ -f "$values" ] || { echo "render: values file not found: $values" >&2; exit 1; }

# Build the sed program as an argument list (one -e per token). Escape the
# replacement-side metacharacters that matter for the `|` delimiter: & \ and |.
sed_args=()
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  key=${line%%=*}; key=${key// /}
  val=${line#*=}
  esc=$(printf '%s' "$val" | sed 's/[&|\]/\\&/g')
  sed_args+=(-e "s|@@${key}@@|${esc}|g")
done < "$values"

if [ "$#" -ge 1 ]; then
  sed "${sed_args[@]}" "$1"
else
  sed "${sed_args[@]}"
fi
