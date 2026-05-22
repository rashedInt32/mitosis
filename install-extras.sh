#!/usr/bin/env bash
#
# install-extras.sh — language-specific global packages.
# Run AFTER install.sh, once the toolchains exist. Failures are non-fatal.

set -uo pipefail

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m  %s\n' "$1"; }

# ── npm globals (needs Node via nvm) ──────────────────────────
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
mkdir -p "$NVM_DIR"
NVM_SH="$(brew --prefix nvm 2>/dev/null)/nvm.sh"
if [ -s "$NVM_SH" ]; then
  # shellcheck disable=SC1090
  . "$NVM_SH"
  command -v node >/dev/null 2>&1 || nvm install --lts
fi
if command -v npm >/dev/null 2>&1; then
  info "Installing npm globals..."
  npm install -g \
    pnpm \
    prettier \
    eslint \
    eslint-plugin-import \
    eslint-plugin-prettier \
    @biomejs/biome \
    @aikidosec/safe-chain
else
  warn "npm not found — skipping npm globals (run 'nvm install --lts' first)"
fi

# ── cargo crates (needs Rust) ─────────────────────────────────
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
if command -v cargo >/dev/null 2>&1; then
  info "Installing cargo crates..."
  cargo install cargo-watch sleek tree-sitter-cli
else
  warn "cargo not found — skipping cargo crates"
fi

# ── go tools (needs Go) ───────────────────────────────────────
if command -v go >/dev/null 2>&1; then
  info "Installing go tools..."
  go install golang.org/x/tools/gopls@latest
  go install honnef.co/go/tools/cmd/staticcheck@latest
else
  warn "go not found — skipping go tools ('brew \"go\"' is in the Brewfile)"
fi

info "Extras done."
