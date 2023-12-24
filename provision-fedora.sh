#!/bin/bash

set -euo pipefail

MINICONDA_DIR=$HOME/miniconda3
ZSH_CUSTOM=$HOME/.config/.oh-my-zsh/custom
NERD_FONT_DIR="$HOME/.local/share/fonts/NerdFonts"

log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

install_dependencies() {
    log "Installing Dependencies..."
    sudo dnf update -y
    sudo dnf install -y which zsh curl wget git util-linux-user dnf-plugins-core procps vim zsh-autosuggestions \
    zsh-syntax-highlighting iproute wireshark-cli pciutils net-tools tcpdump bridge-utils iputils pykickstart \
    koan unzip
}

install_miniconda() {
    if [ ! -d "$MINICONDA_DIR" ]; then
        log "Installing Miniconda3..."
        mkdir -p "$MINICONDA_DIR"
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O "$MINICONDA_DIR/miniconda.sh"
        bash "$MINICONDA_DIR/miniconda.sh" -b -u -p "$MINICONDA_DIR"
        rm -f "$MINICONDA_DIR/miniconda.sh"
        "$MINICONDA_DIR/bin/conda" init bash
        . $HOME/.bashrc || log "Note: Unable to source .bashrc"
    else
        log "Miniconda3 is already installed."
    fi
}

setup_zsh() {
    log "Setting up ZSH..."
    mkdir -p "$ZSH_CUSTOM"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    sed -i '/^plugins=(git/s/)$/ zsh-autosuggestions zsh-syntax-highlighting docker)/' $HOME/.zshrc
    sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="agnoster"/' $HOME/.zshrc
    sed -i '/^# ZSH_CUSTOM=/c\ZSH_CUSTOM=$HOME/.config/.oh-my-zsh/custom' $HOME/.zshrc
    chsh $USER -s "$(which zsh)"
    "$MINICONDA_DIR/bin/conda" init zsh
}

install_docker() {
    log "Installing Docker..."
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable docker
}

install_containerlab() {
    log "Installing Containerlab..."
    curl -SL https://raw.githubusercontent.com/srl-labs/containerlab/main/get.sh -o install-clab.sh
    chmod +x install-clab.sh
    sudo sh install-clab.sh
    rm -f install-clab.sh
}

install_cousine_nerd_font() {
    log "Installing Cousine Nerd Font..."
    mkdir -p "$NERD_FONT_DIR"
    wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Cousine.zip -O "$NERD_FONT_DIR/Cousine.zip"
    unzip -o "$NERD_FONT_DIR/Cousine.zip" -d "$NERD_FONT_DIR"
    rm -f "$NERD_FONT_DIR/Cousine.zip"
    fc-cache -fv
    log "Cousine Nerd Font installation complete."
}

cleanup() {
    log "Cleaning Up..."
    sudo dnf autoremove -y
    sudo dnf clean all
    sudo rm -rf /config/.cache /tmp/*
}

log "Starting script execution..."
install_dependencies
install_miniconda
setup_zsh
install_docker
install_containerlab
install_cousine_nerd_font
cleanup
log "Script execution completed."
