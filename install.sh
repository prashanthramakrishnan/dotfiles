#!/bin/bash
# Symlink these dotfiles into place. Anything already there is moved aside to
# <name>.backup-<timestamp> first, so nothing is lost.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
STAMP=$(date +%Y%m%d-%H%M%S)

link() {
  local src="$DOTFILES/$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "ok       $dest"
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mv "$dest" "$dest.backup-$STAMP"
    echo "backup   $dest -> $dest.backup-$STAMP"
  fi
  ln -s "$src" "$dest"
  echo "linked   $dest -> $src"
}

link ghostty/config              "$HOME/.config/ghostty/config"
link claude/statusline-limits.sh "$HOME/.claude/statusline-limits.sh"

command -v jq >/dev/null || echo "note     the status line needs jq: brew install jq"
fc-list 2>/dev/null | grep -qi 'JetBrains Mono' || ls ~/Library/Fonts 2>/dev/null | grep -qi jetbrains \
  || echo "note     the Ghostty config uses JetBrains Mono: brew install --cask font-jetbrains-mono"

cat <<'MSG'

Done. Two things left to do by hand:
  - Claude Code status line: merge claude/statusline.settings.json into
    ~/.claude/settings.json (it is not linked, because that file holds other settings too).
  - Ghostty: press Cmd+Shift+, (or restart it) to load the config.
MSG
