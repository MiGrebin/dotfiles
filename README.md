# Dotfiles

Personal configuration files for macOS and Linux servers.

## Contents

- **ghostty/** - Ghostty terminal emulator config (macOS)
- **tmux/** - Tmux configuration with catppuccin theme and TPM plugins
- **nvim/** - AstroNvim configuration

## Quick Install (Ubuntu/Debian)

```bash
git clone https://github.com/MiGrebin/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The install script will:
- Install tmux and Neovim (v0.9+ from PPA)
- Install dependencies (git, ripgrep, fd-find, nodejs, npm)
- Set up TPM (Tmux Plugin Manager)
- Symlink tmux and nvim configs (with backups of existing configs)

After installation:
1. Start tmux and press `Ctrl+S` then `I` to install plugins
2. Open `nvim` - AstroNvim will auto-install on first launch

## Manual Installation (macOS)

```bash
# Clone the repo
git clone https://github.com/MiGrebin/dotfiles.git ~/dotfiles

# Ghostty
mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
ln -sf ~/dotfiles/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

# Tmux
ln -sf ~/dotfiles/tmux/.tmux.conf ~/.tmux.conf
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Press prefix + I in tmux to install plugins

# AstroNvim
mv ~/.config/nvim ~/.config/nvim.bak  # backup existing config
ln -sf ~/dotfiles/nvim ~/.config/nvim
```
