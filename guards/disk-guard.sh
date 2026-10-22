#!/bin/bash
# disk-guard: reclaim regenerable disk space. Dry run by default; pass --apply to delete.
# Only touches: package caches, app caches, unused Docker data, stale clean git worktrees,
# the Chrome code_sign_clone leak. Never touches worktrees with unpushed commits or real edits.
set -u
export PATH=/opt/homebrew/bin:/usr/local/bin:"$HOME/.orbstack/bin":/usr/bin:/bin:/usr/sbin:/sbin
APPLY=0; MIN_AGE_DAYS=7; WARN_FREE_GB=30
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --volumes) DOCKER_VOLUMES=1 ;;
    --age=*) MIN_AGE_DAYS="${a#--age=}" ;;
  esac
done
DOCKER_VOLUMES=${DOCKER_VOLUMES:-0}
free_gb() { df -g /System/Volumes/Data | awk 'NR==2{print $4}'; }
say() { echo "[$(date +%H:%M:%S)] $*"; }
run() { if [ "$APPLY" = 1 ]; then "$@"; else say "dry-run: $*"; fi; }
START=$(free_gb); say "free before: ${START}G (apply=$APPLY)"

# 1. package + app caches
if [ "$APPLY" = 1 ]; then
  brew cleanup -s --prune=all >/dev/null 2>&1
  pnpm store prune >/dev/null 2>&1
  # Kept on purpose (2026-10-22): the uv and npm caches feed every Claude/Codex MCP server start,
  # and ~/Library/Caches/Nadir is the shared Xcode build cache. Wiping them at 10:00 made every
  # session redownload and every worktree rebuild from zero, which is what sank the Mac.
  for d in "$HOME"/Library/Caches/*; do
    case "$(basename "$d")" in com.apple.*|CloudKit|FamilyCircle|GeoServices|Nadir) continue ;; esac
    rm -rf "$d" 2>/dev/null
  done
else
  say "dry-run: brew/pnpm cache clean, non-Apple ~/Library/Caches except Nadir ($(du -sh "$HOME/Library/Caches" 2>/dev/null | cut -f1))"
fi

# 2. Docker (only if the daemon is up; volumes need --volumes)
if docker info >/dev/null 2>&1; then
  if [ "$DOCKER_VOLUMES" = 1 ]; then run docker system prune -af --volumes; else run docker system prune -af; fi
fi

# 3. Chrome code_sign_clone leak (only when Chrome is closed)
if ! pgrep -x "Google Chrome" >/dev/null; then
  for c in /private/var/folders/*/*/X/com.google.Chrome.code_sign_clone; do
    [ -d "$c" ] && run rm -rf "$c"
  done
fi

# 4. stale clean worktrees: no commits missing from any remote, no real edits, idle > MIN_AGE_DAYS,
#    and no running process (build, agent, shell) with its working directory inside the worktree.
BUSY=$(mktemp); lsof -a -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | sort -u > "$BUSY"
busy() { awk -v w="$1" 'index($0, w) == 1 { found = 1 } END { exit !found }' "$BUSY"; }
for repo in "$HOME"/GitRepos/*/; do
  repo=${repo%/}; [ -e "$repo/.git" ] || continue
  timeout 60 git -C "$repo" worktree prune 2>/dev/null
  timeout 60 git -C "$repo" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r wt; do
    [ "$wt" = "$repo" ] && continue
    [ -d "$wt" ] || continue
    case "$wt" in "$HOME"/Documents/*) continue ;; esac  # iCloud-synced: git can hang on downloads
    real_wt=$(cd "$wt" && pwd -P)
    if busy "$real_wt" || busy "$wt"; then say "skip, in use: ${wt#$HOME/}"; continue; fi
    gd=$(timeout 20 git -C "$wt" rev-parse --absolute-git-dir 2>/dev/null) || continue
    idx="$gd/index"; [ -e "$idx" ] || idx="$gd/HEAD"
    age=$(( ( $(date +%s) - $(stat -f %m "$idx") ) / 86400 ))
    [ "$age" -ge "$MIN_AGE_DAYS" ] || continue
    uniq=$(timeout 30 git -C "$wt" rev-list --count HEAD --not --remotes 2>/dev/null) || continue
    [ "${uniq:-1}" = 0 ] || continue
    st=$(timeout 30 git -C "$wt" status --porcelain 2>/dev/null) || continue  # timeout must never mean "clean"
    real=$(printf '%s\n' "$st" | grep -v -E '^.. "?(\.agents/|\.claude/skills/)' | grep -v -E '^ M AGENTS\.md$' | grep -c .)
    [ "$real" = 0 ] || continue
    say "stale clean worktree (${age}d): ${wt#$HOME/}"
    run timeout 300 git -C "$repo" worktree remove --force "$wt"
  done
done

rm -f "$BUSY"
END=$(free_gb); say "free after: ${END}G"
if [ "$END" -lt "$WARN_FREE_GB" ]; then
  osascript -e "display notification \"Only ${END} GB free after cleanup. Check ~/Library, Photos, simulators.\" with title \"disk-guard\"" 2>/dev/null
fi
