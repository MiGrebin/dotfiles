# Dotfiles

Personal configuration files for macOS.

## Contents

- **ghostty/** - Ghostty terminal emulator config
- **tmux/** - Tmux configuration with catppuccin theme and TPM plugins
- **nvim/** - AstroNvim configuration

## Installation

```bash
# Clone the repo
git clone https://github.com/MiGrebin/dotfiles.git ~/dotfiles

# Ghostty (macOS)
mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
ln -sf ~/dotfiles/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

# Tmux
ln -sf ~/dotfiles/tmux/.tmux.conf ~/.tmux.conf
# Install TPM if not present
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Then press prefix + I in tmux to install plugins

# AstroNvim
mv ~/.config/nvim ~/.config/nvim.bak  # backup existing config
ln -sf ~/dotfiles/nvim ~/.config/nvim
```
