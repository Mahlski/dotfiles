---
name: dotfiles-bare-repo
description: >
  Encodes the bare-repo dotfiles workflow for this user's setup. Always use this skill
  whenever the user mentions "dotfiles", "my dotfiles", ".dotfiles", or the `dotfiles`
  command/alias. Also trigger when the user is working with config files that are tracked
  by their dotfiles repo — any file under ~/.config/hypr/, ~/.config/fish/,
  ~/.config/kitty/, ~/.config/nvim/, ~/.config/waybar/, ~/.config/dunst/, ~/.config/fuzzel/,
  ~/.config/btop/, ~/.config/mpv/, or ~/.ssh/config. Trigger when the
  user wants to commit, stage, or push config changes, asks about their Hyprland/Kitty/Fish/
  Neovim/Waybar config, or is syncing config between laptop and desktop. Load proactively —
  if there's dotfiles context, use this skill. Do NOT trigger for generic git questions
  unrelated to dotfiles.
---

# dotfiles-bare-repo

This skill encodes the bare-repo dotfiles setup. The authoritative source for current
tracked files and pending work is `~/.dotfiles/CLAUDE.md` — read it at the start of any
dotfiles session.

## How the bare repo works

This is not a standard git repo. The separation is:

- Git internals live in `~/.dotfiles/`
- Working tree is `$HOME` — files live in-place, no symlinks

Because of this split, all git operations need to be routed through the right alias.

## The right command form

**In shell suggestions** (Fish syntax — the user's shell):
```fish
dotfiles status
dotfiles add ~/.config/hypr/hyprland.conf
dotfiles commit -m "hypr: update keybinds"
dotfiles push
dotfiles pull
dotfiles diff
dotfiles log --oneline
```

**In Claude Code tool calls** (non-interactive — the Fish alias isn't available):
```bash
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME status
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME add ~/.config/hypr/hyprland.conf
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME commit -m "hypr: update keybinds"
```

**Never use plain `git` when operating in $HOME** — it would target the wrong repo or error.

## Status output behavior

`dotfiles status` only shows tracked files with changes. Untracked files are hidden by
design (`status.showUntrackedFiles = no`) because $HOME is too noisy. A "clean" status
doesn't mean there's nothing interesting in $HOME — it means nothing tracked has changed.

## Staging rules

Always stage by explicit file path. The two things to avoid:

1. `dotfiles add .` — this is broad and will pick up noise; never suggest it
2. Staging a file without reviewing the diff first — use `dotfiles diff <path>` before staging

Before staging anything, scan for runtime-state files the user wouldn't want to commit
(see the table below). Flag these proactively if they appear in the diff.

## Files to never stage

These are excluded in `~/.gitignore_dotfiles` or are otherwise off-limits:

| File/Pattern | Why |
|---|---|
| `~/.ssh/id_*` | Private keys — absolute never |
| `~/.config/fish/fish_variables` | Fish auto-manages this; it's machine-specific noise |
| `~/.config/nvim/lazy-lock.json` | Machine-specific lockfile, differs per machine |
| `*.bak`, `*.log` | Transient noise |
| `~/.config/Claude/` | App-managed at runtime |
| `~/.config/obsidian/` | App-managed at runtime |
| `~/.config/pulse/`, `~/.config/dconf/`, `~/.config/mozilla/` | Runtime state |
| `~/.config/pcmanfm/` | Mixes prefs and runtime window state — runtime state can't be separated |
| `~/.config/vlc/` | Window geometry and recents are rewritten on every close |

If you're about to suggest staging something matching these patterns, flag it to the
user and ask them to confirm before proceeding.

## Commit message format

Pattern: `component: short imperative description`

The component matches the config subdirectory name: `hypr`, `fish`, `kitty`, `nvim`,
`waybar`, `dunst`, `fuzzel`, `btop`, `mpv`, `ssh`.

For commits touching multiple components: `config: <description>`

Examples from this repo's history:
- `hypr: switch monitor to descriptor, add monitor-switch script`
- `fish: add cc-dot launcher function`
- `nvim: update telescope keybinds`
- `waybar: add battery module for laptop`

## Machine-specific config

This repo is shared between a laptop and a desktop with different hardware (monitors,
GPU, Waybar output names). Machine-specific config is handled via separate files sourced
conditionally by hostname — never flatten them into the shared config. When touching
Hyprland monitor layout, Waybar outputs, or similar hardware-tied settings, check
whether a per-machine split already exists before editing the shared file.

## Setup reference

- Bare repo: `~/.dotfiles/`
- Working tree: `$HOME`
- Gitignore: `~/.gitignore_dotfiles` (set via `core.excludesFile`)
- Pull strategy: `pull.rebase = true` — always rebases, keeps history linear
- Remote: `git@github.com:Mahlski/dotfiles.git`, SSH auth

Read `~/.dotfiles/CLAUDE.md` for the full list of tracked directories and any pending
migration work.
