# mitosis

Personal macOS developer environment. `install.sh` sets it up on a new Mac.

## Layout

| Path                | Purpose                                              |
|---------------------|------------------------------------------------------|
| `install.sh`        | Bootstrap: Homebrew, tools, configs, symlinks        |
| `install-extras.sh` | Optional npm / cargo / go global packages            |
| `Brewfile`          | Homebrew formulae, casks, taps                       |
| `Brewfile.vscode`   | Optional VS Code + extensions                        |
| `config/`           | Symlinked into `~/.config/` (e.g. `config/bat` to `~/.config/bat`) |
| `home/`             | Symlinked into `~/` as dotfiles (`home/gitconfig` to `~/.gitconfig`) |

`nvim`, `zconfig` (zsh), and `ghostty` are separate repos that own their own
config directory. `install.sh` clones them:

- https://github.com/rashedInt32/lazyvim-config  to `~/.config/nvim`
- https://github.com/rashedInt32/zconfig         to `~/.config/zconfig` (provides `~/.zshrc`)
- https://github.com/rashedInt32/ghostty-config  to `~/.config/ghostty`

## Bootstrap a new Mac

```sh
git clone https://github.com/rashedInt32/mitosis.git ~/Documents/codes/packages/mitosis
~/Documents/codes/packages/mitosis/install.sh
```

`install.sh` runs these steps, in order:

1. Xcode Command Line Tools (GUI installer; click through, then re-run)
2. GitHub SSH key. Prompts for your email, generates an `ed25519` key, copies
   the public key to your clipboard, and waits while you add it at
   <https://github.com/settings/ssh/new>. Optional; press `n` to skip.
3. Homebrew
4. Rust
5. `Brewfile`
6. Claude Code CLI
7. oh-my-zsh
8. Clones `nvim` / `zconfig` / `ghostty`
9. Symlinks `~/.config/` entries
10. Symlinks home dotfiles
11. Git identity
12. `tv update-channels` (television cable channels)
13. Misc (tmux TPM, `.hushlogin`)

Then, optionally:

```sh
~/Documents/codes/packages/mitosis/install-extras.sh                   # npm / cargo / go globals
brew bundle --file=~/Documents/codes/packages/mitosis/Brewfile.vscode  # VS Code + extensions
```

The three config repos are public, so they clone without SSH. SSH is only
needed to push config changes back, so the SSH step is recommended but
skippable. Clones fall back to https.

## How it works

`install.sh` is idempotent and safe to re-run. Anything it would overwrite is
moved to `~/mitosis-backup-<timestamp>/` before a symlink takes its place.

Your git identity (name and email) is kept out of this public repo.
`home/gitconfig` includes `~/.gitconfig.local`, an untracked per-machine file
that `install.sh` creates, prompting for or reusing your email.

## Set up manually

These steps are not handled by the script:

- Xcode Command Line Tools: `install.sh` triggers the installer. Click through
  the GUI dialog, then re-run the script.
- Full Xcode.app: only needed for iOS / React Native builds. Install it from
  the App Store, since that requires an App Store sign-in.
- GitHub Copilot: re-auth in nvim with `:Copilot setup`.
- Atuin shell-history sync: `atuin login`.
- Karabiner-Elements permissions: the app is installed by the `Brewfile` and
  its config (`config/karabiner/`) is symlinked, but on first launch macOS
  requires manual approval. Enable the driver / system extension in System
  Settings > Privacy & Security, and grant Input Monitoring.
- `~/.oh-my-zsh`: installed fresh by its own installer.
- RVM and LM Studio `PATH` lines in `home/profile` are machine-specific.
