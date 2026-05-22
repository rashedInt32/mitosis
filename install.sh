#!/usr/bin/env bash
#
# install.sh — bootstrap a macOS developer environment from this repo.
#
# Usage on a fresh Mac:
#   git clone https://github.com/rashedInt32/mitosis.git ~/Documents/codes/packages/mitosis
#   ~/Documents/codes/packages/mitosis/install.sh
#
# Idempotent: re-running is safe. Anything overwritten is moved to
# ~/mitosis-backup-<timestamp>/ first.

set -euo pipefail

# Must run as a normal user. Homebrew refuses to install or run as root, and
# running as root would create root-owned files throughout your home directory.
if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run install.sh as root or with sudo." >&2
  echo "Run it as your normal user; it asks for your password only when needed." >&2
  exit 1
fi

# Repo location derives from this script — works wherever it is cloned.
DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)}"
BACKUP="$HOME/mitosis-backup-$(date +%Y%m%d-%H%M%S)"
GIT_EMAIL=""  # captured during SSH setup, reused for ~/.gitconfig.local

# Repos that own their config directory outright. SSH URLs so `git push`
# works after setup; clone_into() falls back to https if SSH is unavailable.
NVIM_REPO="git@github.com:rashedInt32/lazyvim-config.git"
ZCONFIG_REPO="git@github.com:rashedInt32/zconfig.git"
GHOSTTY_REPO="git@github.com:rashedInt32/ghostty-config.git"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m  %s\n' "$1"; }
ok()   { printf '\033[1;32m[ok]\033[0m %s\n' "$1"; }

# True if SSH to GitHub already authenticates. `ssh -T git@github.com` always
# exits non-zero (no shell access), so match the success message instead.
github_ssh_ok() {
  local out
  out="$(ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
            -o BatchMode=yes git@github.com 2>&1 || true)"
  printf '%s' "$out" | grep -q 'successfully authenticated'
}

# Generate a GitHub SSH key, hand the public half to the user, wait for them
# to register it. Optional — clones fall back to https if skipped.
setup_github_ssh() {
  if github_ssh_ok; then
    ok "GitHub SSH already authenticated"
    return
  fi

  echo
  echo "GitHub SSH lets you PUSH config changes back and clone private repos."
  echo "Your nvim/zsh/ghostty repos are public (cloning works without it), but"
  echo "set it up now if you want two-way sync."
  printf 'Set up a GitHub SSH key now? [Y/n] '
  local ans=""; read -r ans || true
  case "$ans" in
    [Nn]*) warn "Skipping SSH — repos will clone over https (read-only)."; return ;;
  esac

  local key="$HOME/.ssh/id_ed25519"
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"

  if [ -f "$key" ]; then
    ok "Reusing existing SSH key: $key"
  else
    while [ -z "${GIT_EMAIL:-}" ]; do
      printf 'Enter your GitHub email (used as the key label): '
      read -r GIT_EMAIL || true
    done
    info "Generating an ed25519 SSH key (no passphrase)..."
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$key" -N ""
  fi

  # Tell ssh to use this key for github.com
  touch "$HOME/.ssh/config"; chmod 600 "$HOME/.ssh/config"
  if ! grep -q 'Host github.com' "$HOME/.ssh/config"; then
    printf '\nHost github.com\n  AddKeysToAgent yes\n  IdentityFile %s\n' \
      "$key" >> "$HOME/.ssh/config"
  fi

  pbcopy < "$key.pub"
  echo
  bold "Your PUBLIC SSH key is on the clipboard. Add it to GitHub:"
  echo "  1. Open   https://github.com/settings/ssh/new"
  echo "  2. Paste the key, give it a title, click 'Add SSH key'"
  echo
  echo "If the clipboard didn't take, copy this line:"
  echo "  $(cat "$key.pub")"
  echo
  while true; do
    printf 'Press Return once the key is saved on GitHub (or type s to skip)... '
    local r=""; read -r r || true
    [ "$r" = "s" ] && { warn "Skipping verification — clones will use https."; return; }
    if github_ssh_ok; then
      ok "GitHub SSH authenticated"
      return
    fi
    warn "Not authenticated yet — confirm the key is saved on GitHub, then retry."
  done
}

# Write ~/.gitconfig.local with the user's identity. This file is NOT in the
# dotfiles repo — it keeps the public repo free of personal email/name.
setup_git_identity() {
  local local_cfg="$HOME/.gitconfig.local"
  if [ -f "$local_cfg" ]; then
    ok "git identity present ($local_cfg)"
    return
  fi
  while [ -z "${GIT_EMAIL:-}" ]; do
    printf 'Git email (for commit authorship): '
    read -r GIT_EMAIL || true
  done
  local name=""
  printf 'Git author name (optional, Return to skip): '
  read -r name || true
  {
    echo "# Machine-local git identity — not tracked by the dotfiles repo."
    echo "[user]"
    printf '\temail = %s\n' "$GIT_EMAIL"
    [ -n "$name" ] && printf '\tname = %s\n' "$name"
  } > "$local_cfg"
  ok "wrote $local_cfg"
}

# Clone a repo, preferring SSH, falling back to https (works for public repos).
clone_into() { # $1 = ssh url, $2 = destination
  local url="$1" dest="$2"
  if [ -d "$dest/.git" ]; then
    ok "$(basename "$dest"): already a git repo (skipped)"
    return
  fi
  if [ -e "$dest" ]; then
    mkdir -p "$BACKUP"
    mv "$dest" "$BACKUP/"
    warn "backed up $dest -> $BACKUP/"
  fi
  if git clone "$url" "$dest" 2>/dev/null; then
    ok "cloned $(basename "$dest") via ssh"
  else
    local https="${url/git@github.com:/https://github.com/}"
    warn "$(basename "$dest"): ssh clone failed — using https"
    git clone "$https" "$dest"
    ok "cloned $(basename "$dest") via https"
  fi
}

# Move an existing path out of the way, then symlink repo -> destination.
backup_and_link() { # $1 = source in repo, $2 = destination
  local src="$1" dest="$2"
  if [ -L "$dest" ]; then
    [ "$(readlink "$dest")" = "$src" ] && { ok "linked: $dest"; return; }
    rm "$dest"
  elif [ -e "$dest" ]; then
    mkdir -p "$BACKUP"
    mv "$dest" "$BACKUP/"
    warn "backed up $dest -> $BACKUP/"
  fi
  ln -s "$src" "$dest"
  ok "linked: $dest -> $src"
}

[ -d "$DOTFILES" ] || {
  echo "Put this repo at $DOTFILES first, then re-run." >&2
  exit 1
}

# ── Sanity check: ZIP download / unstable location ────────────
# install.sh symlinks every config back to $DOTFILES, so the repo must sit at
# a stable path and be a real git clone. A ZIP unpacked in ~/Downloads fails
# both: the symlinks break when the folder is moved or cleared, and
# git pull / git push (the point of two-way sync) will not work.
not_git=false; in_downloads=false
[ -d "$DOTFILES/.git" ] || not_git=true
case "$DOTFILES" in "$HOME/Downloads"/*) in_downloads=true ;; esac

if [ "$not_git" = true ] || [ "$in_downloads" = true ]; then
  warn "This repo may be in the wrong place to install from:"
  [ "$not_git" = true ]      && echo "    - it is not a git repo (looks like a ZIP download)"
  [ "$in_downloads" = true ] && echo "    - it is inside ~/Downloads"
  echo "  install.sh will symlink your configs back to:"
  echo "    $DOTFILES"
  echo "  That path must be stable and a real git clone, or the symlinks break"
  echo "  if it moves and 'git pull' / 'git push' will not work."
  echo "  Recommended: clone with git into ~/Documents/codes/packages/mitosis,"
  echo "  then run install.sh from there."
  printf 'Continue anyway? [y/N] '
  ans=""; read -r ans || true
  case "$ans" in
    [Yy]*) warn "Continuing from $DOTFILES." ;;
    *) echo "Aborted. Re-run from a proper git clone."; exit 1 ;;
  esac
fi

bold "Bootstrapping developer environment from $DOTFILES"

# ── 1. Xcode Command Line Tools ───────────────────────────────
if ! xcode-select -p >/dev/null 2>&1; then
  info "Installing Xcode Command Line Tools..."
  xcode-select --install || true
  warn "Finish the Xcode CLT installer window, then re-run this script."
  exit 0
fi
ok "Xcode Command Line Tools present"

# ── 2. GitHub SSH key ─────────────────────────────────────────
setup_github_ssh

# ── 3. Homebrew ───────────────────────────────────────────────
if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$p" ] && eval "$("$p" shellenv)"
done
ok "Homebrew ready"

# ── 4. Rust — ~/.zshenv sources ~/.cargo/env unconditionally ──
if ! command -v cargo >/dev/null 2>&1; then
  info "Installing Rust (rustup)..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
ok "Rust ready"

# ── 5. Homebrew bundle ────────────────────────────────────────
info "Installing tools from Brewfile (this takes a while)..."
brew bundle --file="$DOTFILES/Brewfile" || \
  warn "Some Brewfile entries failed — review the output above."
ok "Brewfile processed"

# ── 6. Claude Code CLI ────────────────────────────────────────
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
  info "Installing Claude Code CLI..."
  curl -fsSL https://claude.ai/install.sh | bash
fi
if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
  ok "Claude Code ready"
else
  warn "Claude Code install may have failed — review the output above."
fi

# ── 7. oh-my-zsh ──────────────────────────────────────────────
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  info "Installing oh-my-zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ok "oh-my-zsh ready"

# ── 8. Config repos that manage their own directory ───────────
mkdir -p "$HOME/.config"
clone_into "$NVIM_REPO"    "$HOME/.config/nvim"
clone_into "$ZCONFIG_REPO" "$HOME/.config/zconfig"
clone_into "$GHOSTTY_REPO" "$HOME/.config/ghostty"

# ── 9. Symlink ~/.config entries ──────────────────────────────
# The .[!.]* glob also catches dotfile dirs like .local (skips . and ..).
info "Linking ~/.config entries..."
for item in "$DOTFILES"/config/* "$DOTFILES"/config/.[!.]*; do
  [ -e "$item" ] || continue
  backup_and_link "$item" "$HOME/.config/$(basename "$item")"
done

# ── 10. Symlink home dotfiles ─────────────────────────────────
info "Linking home dotfiles..."
for item in "$DOTFILES"/home/*; do
  [ -e "$item" ] || continue
  backup_and_link "$item" "$HOME/.$(basename "$item")"
done
# ~/.zshrc lives in the zconfig repo
backup_and_link "$HOME/.config/zconfig/.zshrc" "$HOME/.zshrc"

# ── 11. Git identity (~/.gitconfig.local — kept out of the repo) ──
setup_git_identity

# ── 12. Television cable channels ─────────────────────────────
# config/television/cable/ is gitignored — tv re-fetches it from github
# into the symlinked ~/.config/television/ created in step 9.
if command -v tv >/dev/null 2>&1; then
  info "Fetching television cable channels..."
  tv update-channels || warn "tv update-channels failed — run 'tv update-channels' later."
else
  warn "television (tv) not found — skipping cable channels (check the Brewfile step)."
fi

# ── 13. Misc ──────────────────────────────────────────────────
touch "$HOME/.hushlogin"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  info "Installing tmux plugin manager (TPM)..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

ZSH_PATH="$(command -v zsh || true)"
if [ -n "$ZSH_PATH" ] && [ "${SHELL:-}" != "$ZSH_PATH" ]; then
  warn "Make zsh your login shell:  chsh -s $ZSH_PATH"
fi

bold "Done."
cat <<EOF

Next steps (manual):
  - Restart your terminal, or:  exec zsh
  - Run 'claude' and sign in on first launch
  - Open nvim — LazyVim installs its plugins on first launch
  - In tmux, press <prefix> + I to install plugins via TPM
  - atuin login                  # restore shell-history sync
  - In nvim, :Copilot setup      # re-auth GitHub Copilot
  - $DOTFILES/install-extras.sh                   # npm / cargo / go globals
  - brew bundle --file=$DOTFILES/Brewfile.vscode  # VS Code + extensions (optional)
EOF
[ -d "$BACKUP" ] && echo "  - Replaced files were backed up to: $BACKUP"
echo
