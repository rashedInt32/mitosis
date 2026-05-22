#!/usr/bin/env bash
#
# uninstall.sh — reverse what install.sh set up on this machine.
#
# Removes the symlinks, cloned config repos, and tools install.sh created,
# including Homebrew and every package on the machine.
#
# Run as a normal user — NOT root, NOT with sudo. Re-runnable.
#
# Usage:
#   ~/Documents/codes/packages/mitosis/uninstall.sh        # asks once, then runs
#   ~/Documents/codes/packages/mitosis/uninstall.sh -y     # skip the prompt

set -euo pipefail

# Must run as a normal user. Running as root would have left root-owned files
# in your home directory, and Homebrew refuses to run as root anyway.
if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run uninstall.sh as root or with sudo." >&2
  echo "Run it as your normal user; it asks for your password only when needed." >&2
  exit 1
fi

# Repo location derives from this script — works wherever it is cloned.
DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)}"

ASSUME_YES=false
case "${1:-}" in
  -y|--yes) ASSUME_YES=true ;;
esac

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m  %s\n' "$1"; }
ok()   { printf '\033[1;32m[ok]\033[0m %s\n' "$1"; }

# Refuse to run from anywhere that is not the mitosis repo — the config/ and
# home/ folders below must be the same ones install.sh linked from.
if [ ! -f "$DOTFILES/install.sh" ] || [ ! -f "$DOTFILES/Brewfile" ]; then
  echo "uninstall.sh must live inside the mitosis repo. Found: $DOTFILES" >&2
  exit 1
fi

# Remove $1 only if it is a symlink that points back into this repo. Real
# files, directories, and symlinks pointing elsewhere are left untouched.
unlink_if_ours() { # $1 = path to remove
  local dest="$1" target
  if [ -L "$dest" ]; then
    target="$(readlink "$dest")"
    case "$target" in
      "$DOTFILES"/*)
        rm "$dest"
        ok "unlinked: $dest"
        return ;;
    esac
    warn "skipped (symlink points outside the repo): $dest -> $target"
  elif [ -e "$dest" ]; then
    warn "skipped (not a symlink — left as-is): $dest"
  fi
}

# ── Plan & confirmation ───────────────────────────────────────
bold "uninstall.sh will reverse install.sh on this machine:"
echo "  - symlinks in ~/.config and ~/ that point into $DOTFILES"
echo "  - cloned repos: ~/.config/{nvim,zconfig,ghostty}, ~/.tmux/plugins/tpm"
echo "  - ~/.gitconfig.local and ~/.hushlogin"
echo "  - Claude Code CLI, oh-my-zsh, Rust (rustup)"
echo "  - Homebrew AND every Homebrew package on this machine"
echo
echo "Left in place (see notes at the end): your SSH key, Xcode Command Line"
echo "Tools, the ~/mitosis-backup-* folders, ~/.claude, and this repo itself."
echo
warn "Homebrew removal affects ALL brew packages, not just this repo's Brewfile."

if [ "$ASSUME_YES" != true ]; then
  echo
  printf 'Continue? [y/N] '
  ans=""; read -r ans || true
  case "$ans" in
    [Yy]*) ;;
    *) echo "Aborted. Nothing was removed."; exit 0 ;;
  esac
fi
echo

# ── 1. Remove ~/.config symlinks ──────────────────────────────
info "Removing ~/.config symlinks..."
for item in "$DOTFILES"/config/* "$DOTFILES"/config/.[!.]*; do
  [ -e "$item" ] || continue
  unlink_if_ours "$HOME/.config/$(basename "$item")"
done

# ── 2. Remove home dotfile symlinks ───────────────────────────
info "Removing home dotfile symlinks..."
for item in "$DOTFILES"/home/*; do
  [ -e "$item" ] || continue
  unlink_if_ours "$HOME/.$(basename "$item")"
done
# ~/.zshrc points into the zconfig repo, not $DOTFILES — handle it separately.
if [ -L "$HOME/.zshrc" ]; then
  zshrc_target="$(readlink "$HOME/.zshrc")"
  case "$zshrc_target" in
    *"/.config/zconfig/.zshrc")
      rm "$HOME/.zshrc"; ok "unlinked: $HOME/.zshrc" ;;
    *)
      warn "skipped (~/.zshrc points elsewhere): $zshrc_target" ;;
  esac
fi

# ── 3. Remove cloned config repos ─────────────────────────────
info "Removing cloned config repos..."
for d in "$HOME/.config/nvim" "$HOME/.config/zconfig" \
         "$HOME/.config/ghostty" "$HOME/.tmux/plugins/tpm"; do
  if [ -d "$d" ]; then
    if [ -d "$d/.git" ] && [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ]; then
      warn "$d has uncommitted changes — removing anyway."
    fi
    rm -rf "$d"
    ok "removed $d"
  fi
done
# Clean up now-empty tmux dirs.
rmdir "$HOME/.tmux/plugins" "$HOME/.tmux" 2>/dev/null || true

# ── 4. Remove files install.sh wrote ──────────────────────────
info "Removing files install.sh wrote..."
for f in "$HOME/.gitconfig.local" "$HOME/.hushlogin"; do
  if [ -f "$f" ]; then rm "$f"; ok "removed $f"; fi
done

# ── 5. Uninstall Claude Code CLI ──────────────────────────────
info "Removing Claude Code CLI..."
if [ -e "$HOME/.local/bin/claude" ]; then
  rm -f "$HOME/.local/bin/claude"
  ok "removed Claude Code CLI (login/settings in ~/.claude left intact)"
else
  ok "Claude Code CLI not present"
fi

# ── 6. Uninstall oh-my-zsh ────────────────────────────────────
info "Removing oh-my-zsh..."
if [ -d "$HOME/.oh-my-zsh" ]; then
  rm -rf "$HOME/.oh-my-zsh"
  ok "removed ~/.oh-my-zsh"
else
  ok "oh-my-zsh not present"
fi

# ── 7. Uninstall Rust ─────────────────────────────────────────
info "Removing Rust (rustup)..."
if command -v rustup >/dev/null 2>&1; then
  rustup self uninstall -y || warn "rustup uninstall reported an error — review above."
  ok "rustup uninstalled"
elif [ -d "$HOME/.cargo" ] || [ -d "$HOME/.rustup" ]; then
  rm -rf "$HOME/.cargo" "$HOME/.rustup"
  ok "removed ~/.cargo and ~/.rustup"
else
  ok "Rust not present"
fi

# ── 8. Uninstall Homebrew (and every package) ─────────────────
info "Removing Homebrew and all its packages..."
brew_bin=""
for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$p" ] && brew_bin="$p"
done
if [ -n "$brew_bin" ] || command -v brew >/dev/null 2>&1; then
  warn "The Homebrew uninstaller runs next. It removes brew and EVERY package,"
  warn "asks for its own confirmation, and prompts for your sudo password."
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" \
    || warn "Homebrew uninstaller reported an error — review the output above."
  ok "Homebrew uninstaller finished"
else
  ok "Homebrew not present"
fi

# ── Done ──────────────────────────────────────────────────────
bold "Uninstall complete."
cat <<EOF

Left in place on purpose:
  - SSH key (~/.ssh/id_ed25519). It may be your only access to GitHub.
    To remove it yourself:
      rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
    then delete the 'Host github.com' block from ~/.ssh/config and remove the
    key at https://github.com/settings/keys
  - Xcode Command Line Tools. No clean uninstall, and other tooling needs it.
    If you really want it gone:  sudo rm -rf /Library/Developer/CommandLineTools
  - ~/mitosis-backup-* folders — your pre-install originals, if any.
  - ~/.claude — Claude Code login and settings.
  - This repo. Delete it last with:  rm -rf "$DOTFILES"

Restart your terminal to pick up a clean shell environment.
EOF
echo
