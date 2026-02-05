#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if running on Ubuntu/Debian
if ! command -v apt &> /dev/null; then
    error "This script requires apt (Ubuntu/Debian)"
fi

info "Updating package lists..."
sudo apt update

# Install tmux
if command -v tmux &> /dev/null; then
    info "tmux is already installed: $(tmux -V)"
else
    info "Installing tmux..."
    sudo apt install -y tmux
fi

# Install neovim (need recent version for AstroNvim)
install_neovim() {
    info "Installing Neovim..."

    # Check if we have a recent enough version
    if command -v nvim &> /dev/null; then
        NVIM_VERSION=$(nvim --version | head -n1 | grep -oP 'v\K[0-9]+\.[0-9]+')
        if (( $(echo "$NVIM_VERSION >= 0.9" | bc -l) )); then
            info "Neovim $NVIM_VERSION is already installed and sufficient"
            return
        else
            warn "Neovim $NVIM_VERSION is too old, installing newer version..."
        fi
    fi

    # Add the unstable PPA for latest neovim (AstroNvim needs 0.9+)
    sudo apt install -y software-properties-common
    sudo add-apt-repository -y ppa:neovim-ppa/unstable
    sudo apt update
    sudo apt install -y neovim
}

install_neovim

# Install dependencies for AstroNvim
info "Installing dependencies (git, ripgrep, fd-find, nodejs, npm)..."
sudo apt install -y git ripgrep fd-find nodejs npm

# Setup tmux config
info "Setting up tmux configuration..."
if [ -f "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
    warn "Backing up existing .tmux.conf to .tmux.conf.bak"
    mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak"
fi
ln -sf "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"

# Install TPM (Tmux Plugin Manager)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    info "Installing TPM (Tmux Plugin Manager)..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
    info "TPM is already installed"
fi

# Setup nvim config
info "Setting up Neovim configuration..."
mkdir -p "$HOME/.config"

if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    warn "Backing up existing nvim config to ~/.config/nvim.bak"
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
elif [ -L "$HOME/.config/nvim" ]; then
    rm "$HOME/.config/nvim"
fi
ln -sf "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

info "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Start tmux and press 'prefix + I' to install tmux plugins"
echo "     (Your prefix is Ctrl+S)"
echo "  2. Open nvim - AstroNvim will auto-install plugins on first launch"
