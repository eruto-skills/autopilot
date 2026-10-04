#!/usr/bin/env bash
# Installs the autopilot skill into ~/.claude/skills/ on macOS and Linux.
# Idempotent: re-running on an already-linked path is safe.
#
# Manual equivalent (if you can't run this script):
#   ln -s /path/to/eruto-skills/autopilot ~/.claude/skills/autopilot
#
# Why a symlink: same effect as the Windows Junction. On macOS/Linux symlinks
# don't need elevated permissions.

set -euo pipefail

# Resolve the autopilot/ repo directory from this script's location.
# On macOS, readlink -f isn't BSD-stock; we fall back to a perl one-liner.
if command -v greadlink >/dev/null 2>&1; then
  readlink_f() { greadlink -f "$1"; }
elif readlink -f / >/dev/null 2>&1; then
  readlink_f() { readlink -f "$1"; }
else
  readlink_f() { perl -MCwd=abs_path -e 'print abs_path(shift)' "$1"; }
fi

script_dir="$(cd "$(dirname "$(readlink_f "${BASH_SOURCE[0]}")")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

host=claude
force=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) host="${2:?--host needs claude or codex}"; shift 2 ;;
    --force) force=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
case "$host" in
  claude) skills_dir="$HOME/.claude/skills" ;;
  codex) skills_dir="$HOME/.agents/skills" ;;
  *) echo "Unknown host: $host" >&2; exit 1 ;;
esac
link_path="$skills_dir/autopilot"


mkdir -p "$skills_dir"

if [ -L "$link_path" ]; then
  current="$(readlink_f "$link_path")"
  if [ "$current" = "$repo_root" ]; then
    echo "already linked: $link_path -> $repo_root"
    exit 0
  fi
  if [ "$force" = "1" ]; then
    echo "removing existing symlink: $link_path -> $current"
    rm "$link_path"
  else
    echo "ERROR: $link_path points to $current (expected $repo_root)" >&2
    echo "       re-run with --force to replace" >&2
    exit 1
  fi
elif [ -e "$link_path" ]; then
  echo "ERROR: $link_path exists and is not a symlink" >&2
  echo "       re-run with --force to replace" >&2
  echo "Only an existing symlink can be replaced; preserve the directory." >&2
  exit 1
fi

ln -s "$repo_root" "$link_path"
echo "created symlink: $link_path -> $repo_root"
