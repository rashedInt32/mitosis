# Brewfile — curated dev environment for a fresh macOS machine.
# Apply with:  brew bundle --file=~/dotfiles/Brewfile
#
# VS Code + extensions:  see Brewfile.vscode (optional)
# npm / cargo / go globals: installed by install-extras.sh

# ── Taps ──────────────────────────────────────────────────────
tap "homebrew/services"
tap "gromgit/brewtils"        # taproom
tap "jesseduffield/lazygit"
tap "ngrok/ngrok"
tap "shivammathur/php"        # php@8.1 / php@8.3
tap "sst/tap"                 # opencode
tap "koekeishiya/formulae"    # no formula used below — remove if unneeded
tap "steipete/tap"            # no formula used below — remove if unneeded

# ── Shell & terminal ──────────────────────────────────────────
brew "atuin"                  # shell history sync
brew "carapace"               # multi-shell completions
brew "fzf"                    # fuzzy finder
brew "tmux"
brew "thefuck"
brew "television"             # tv fuzzy picker
brew "gh"                     # GitHub CLI

# ── Editors ───────────────────────────────────────────────────
brew "neovim"
brew "stylua"                 # lua formatter (nvim config)
brew "luarocks"

# ── AI coding tools ───────────────────────────────────────────
brew "opencode"
brew "qwen-code"

# ── CLI tools ─────────────────────────────────────────────────
brew "bat"                    # cat with syntax highlighting
brew "eza"                    # modern ls
brew "fd"                     # modern find
brew "ripgrep"
brew "tree"
brew "coreutils"
brew "git-delta"              # nicer git diffs
brew "lazygit"
brew "jj"                     # jujutsu VCS
brew "hl"                     # log highlighter
brew "yq"                     # YAML/JSON processor
brew "lolcat"
brew "youtube-dl"             # deprecated upstream — consider yt-dlp
brew "gromgit/brewtils/taproom"

# ── System monitoring ─────────────────────────────────────────
brew "asitop"
brew "mactop"

# ── Languages & runtimes ──────────────────────────────────────
brew "go"                     # required by install-extras.sh go tools
brew "elixir"
brew "nvm"                    # Node version manager
brew "python@3.12"
brew "python@3.14"
brew "ruby", link: true
brew "zig"
brew "shivammathur/php/php@8.1"
brew "shivammathur/php/php@8.3"

# ── Language package managers ─────────────────────────────────
brew "composer"               # PHP
brew "cocoapods"              # iOS / React Native
brew "gradle"                 # JVM build tool

# ── Databases ─────────────────────────────────────────────────
brew "mysql"
brew "postgresql@14"
brew "postgresql@18", restart_service: :changed

# ── Build tooling & libraries ─────────────────────────────────
brew "autoconf"
brew "automake"
brew "cmake"
brew "libtool"
brew "pkgconf"
brew "ragel"
brew "libpng"
brew "libksba"
brew "openssl@1.1"
brew "zlib"
brew "zstd"

# ── Media & documents ─────────────────────────────────────────
brew "ffmpeg"
brew "imagemagick"
brew "ghostscript"
brew "poppler"
brew "tectonic"               # self-contained LaTeX engine
brew "mermaid-cli"
brew "wordnet"

# ── Casks (GUI apps) ──────────────────────────────────────────
cask "ghostty"                # terminal emulator
cask "stats"                  # menu-bar system monitor
cask "notunes"                # block Apple Music auto-launch
cask "karabiner-elements"     # keyboard customiser (config in config/karabiner)
cask "emacs-app"
cask "react-native-debugger"
cask "ngrok/ngrok/ngrok"
