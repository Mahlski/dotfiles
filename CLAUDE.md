# CLAUDE.md — Dotfiles Repo

Repo-specific context for Claude Code. Extends `~/.claude/CLAUDE.md`.

---

## Repo Structure

This is a **GNU stow** repo — a normal git repo whose contents are symlinked into
`$HOME`. Migrated from a bare git repo on 2026-05-16.

- Repo root and stow directory: `~/dotfiles/`
- Stow target: `$HOME` (the stow dir's parent — the default)
- Each top-level folder is a **stow package**; inside it, the file tree mirrors the
  path relative to `$HOME`.

```
~/dotfiles/
├── config/   → .config/*   (dunst, fish, hypr, kitty, nvim, waybar, …)
├── claude/   → .claude/*   (selected skills + statusline-command.sh)
├── ssh/      → .ssh/config (config only — never keys)
└── local/    → .local/bin/setup/
```

---

## Workflow

Normal git — `git status` shows everything, untracked files included.

```fish
cd ~/dotfiles
git status
git add config/.config/hypr/hyprland.lua
git commit -m "hypr: update keybinds"
git push
```

### Adding a new file

A file is tracked only if it lives in a package. To add one:

```fish
mv ~/.config/foo/bar.conf ~/dotfiles/config/.config/foo/bar.conf
cd ~/dotfiles && stow config        # re-link
```

### Deploying on a fresh machine

```fish
git clone git@github.com:Mahlski/dotfiles.git ~/dotfiles
cd ~/dotfiles && stow config claude ssh local
chmod 600 ~/dotfiles/ssh/.ssh/config
systemctl --user daemon-reload
```

---

## Gitignore

Repo-root `.gitignore`. Excludes machine-specific / runtime state that rides along
inside whole-directory packages: `fish_variables`, `nvim/lazy-lock.json`,
`nvim/.claude/`, `*.bak`, `*.log`, and any `~/.ssh` key files.

---

## Caveats

- **GUI-rewritten configs** — `nwg-look` and `qt5ct` regenerate `gtk-3.0/`,
  `gtk-4.0/`, `nwg-look/config`, `qt5ct.conf`. An atomic-rename save can replace the
  symlink with a real file. After using those tools, check `git status`; if a symlink
  reverted to a real file, move it back into the package and re-stow.
- **ssh** — ssh follows the symlinked `config`; the real file must be `600`.
- **systemd** — user units are symlinks; run `systemctl --user daemon-reload` after
  changes.

---

## Machine-Specific Config

Two machines share this repo — laptop (`aribook`) and desktop, with different hardware
(GPU, monitors). Machine-specific config (hyprland monitor layout, waybar output
names) is handled via separate files sourced conditionally by hostname. Don't flatten
these into shared files.

---

## GitHub Remote

- **Remote:** `git@github.com:Mahlski/dotfiles.git`
- **Auth:** SSH
