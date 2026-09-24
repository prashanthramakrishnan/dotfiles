# dotfiles

My terminal setup: [Ghostty](https://ghostty.org) config and a Claude Code status line.

## Install

```bash
git clone <this repo> ~/Documents/Codebase/Personal/dotfiles
~/Documents/Codebase/Personal/dotfiles/install.sh
```

`install.sh` symlinks each file into place, so editing a file here changes the live
setup, and vice versa. Anything already at a target path is moved to
`<name>.backup-<timestamp>` first.

Prerequisites:

```bash
brew install --cask font-jetbrains-mono   # Ghostty font
brew install jq                           # the status line parses JSON with it
```

## What's here

### `ghostty/config` → `~/.config/ghostty/config`

- Catppuccin Mocha theme, JetBrains Mono 14, a little window padding, blinking bar cursor
- ~100 MB scrollback for long logs
- `Cmd+Ctrl+Shift+Arrow` resizes splits by 20 px (the default `Cmd+Ctrl+Arrow` is often
  taken by window managers like Rectangle or Raycast)

> **Heads-up: Cmd+V is changed.** It sends Ctrl+V so screenshots paste into Claude Code.
> Plain text paste moves to **Cmd+Shift+V**. Delete the two `keybind = cmd+v` /
> `cmd+shift+v` lines if you don't use Claude Code.

Reload after editing: `Cmd+Shift+,`. Everything not set here is a Ghostty default; list
them with `ghostty +list-keybinds --default`.

### `claude/statusline-limits.sh` → `~/.claude/statusline-limits.sh`

A three-line Claude Code status line:

```
Opus 5.5 · my-repo  main ✓ · 42m
chat ctx █░░░░░░░░░ 12% · 120k/1M · +340 −52 lines · $1.20
session ███░░░░░░░ 31% · in 2h 10m   weekly █░░░░░░░░░ 9% · Tue 02:44
```

- **Line 1:** model, repo, git branch (`✓` clean, `●` uncommitted changes), chat duration
- **chat ctx:** how full this chat's context window is. Near full, older parts get
  summarized and details can be lost; `/clear` or a new chat resets it.
- **session / weekly:** your Claude plan's 5-hour and 7-day usage limits, across all
  chats. Shown only for Pro/Max plans, after the first reply.

Meters are green below 50%, yellow to 80%, red above.

To enable it, merge `claude/statusline.settings.json` into `~/.claude/settings.json`.
