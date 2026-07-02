#!/usr/bin/env bash
# render.sh - substitute @@TOKEN@@ placeholders from a values file.
#
# Values file: `KEY=value` lines; blank lines and `#` comments ignored. A token
# `@@KEY@@` anywhere in the input is replaced by the matching value. Tokens are
# `@@`-delimited so no key can be a prefix of another at the match boundary, and
# the substitution is a single sed pass (order-independent).
#
# Any `@@KEY@@`-shaped token still present after substitution (key missing from
# the values file, or a typo in the template) is reported on stderr so it cannot
# leak silently into a live file. The render still succeeds by default; set
# RENDER_STRICT=1 to turn unresolved placeholders into a hard failure (exit 1,
# nothing written to stdout's consumer if they redirect afterwards).
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

# Render to a temp file first so the output can be checked for unresolved
# tokens without altering it (command substitution would eat trailing newlines).
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if [ "$#" -ge 1 ]; then
  sed "${sed_args[@]}" "$1" > "$tmp"
  src_label="$1"
else
  sed "${sed_args[@]}" > "$tmp"
  src_label="<stdin>"
fi

leftover=$(grep -oE '@@[A-Za-z_][A-Za-z0-9_]*@@' "$tmp" | sort -u || true)
if [ -n "$leftover" ]; then
  printf 'render: WARNING: unresolved placeholder(s) in %s: %s\n' \
    "$src_label" "$(printf '%s' "$leftover" | tr '\n' ' ')" >&2
  if [ "${RENDER_STRICT:-0}" = "1" ]; then
    echo "render: failing because RENDER_STRICT=1" >&2
    exit 1
  fi
fi

cat "$tmp"
