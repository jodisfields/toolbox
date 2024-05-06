#!/bin/bash

USER_HOME="${1:-/home/jodis}"
MINICONDA_DIR="$USER_HOME/miniconda3"
ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"
NERD_FONT_DIR="$USER_HOME/.local/share/fonts/NerdFonts"
NVS_HOME="$USER_HOME/.nvs"
TMP_DIR="/tmp"
LOG_FILE="$USER_HOME/post-install.log"
releasever=$(rpm -E %fedora)
basearch=$(uname -m)

log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >>"$LOG_FILE"
}

handle_error() {
    log "Error occurred: $1"
    exit 1
}

download_file() {
    local url=$1
    local dest=$2
    wget "$url" -O "$dest" || handle_error "Failed to download $url"
}

run_cmd() {
    "$@" || handle_error "Command failed: $*"
}

require_tool() {
    if ! command -v $1 &>/dev/null; then
        handle_error "Required tool $1 is not installed."
    fi
}

check_prerequisites() {
    log "Checking prerequisites..."
    require_tool wget
    require_tool git
    require_tool curl
}

disable_selinux() {
    log "Disabling SELinux..."
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config || handle_error "Failed to disable SELinux"
}

disable_firewall() {
    log "Disabling Firewall..."
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld || handle_error "Failed to disable Firewall"
}

add_repositories() {
    log "Adding Repositories..."
    run_cmd sudo dnf config-manager --add-repo=https://pkg.surfacelinux.com/fedora/linux-surface.repo
    run_cmd sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
    run_cmd sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
    run_cmd sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    run_cmd sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    run_cmd sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    run_cmd sudo dnf update -y
}

install_packages() {
    log "Installing packages..."
    run_cmd sudo dnf update -y
    run_cmd sudo dnf install --allowerasing -y kernel-surface iptsd libwacom-surface
    run_cmd sudo systemctl enable --now linux-surface-default-watchdog.path
    run_cmd sudo dnf install -y \
        which zsh ansible curl fzf zsh-autosuggestions zsh-syntax-highlighting gh docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin wget git vim virt-manager libvirt qemu qemu-kvm qemu-tools syslinux code-insiders \
        firefox gcc genisoimage glibc gnome-desktop4 gnome-shell gnome-shell-extension-common gnome-shell-extension-pop-shell \
        gnome-shell-extension-pop-shell-shortcut-overrides gnome-tweaks graphviz grub2-common grub2-efi-x64 alacritty grub2-tools \
        libvirt-daemon neovim openssh-server openssl pykickstart python3 qemu-common qemu-img redhat-rpm-config squashfs-tools \
        virt-install virt-manager-common wpa_supplicant xclip xorriso ngrep unzip util-linux-user dnf-plugins-core procps 1password \
        iproute wireshark-cli pciutils net-tools tcpdump bridge-utils iputils koan libuser
}

install_nvs() {
    mkdir -p $NVS_HOME
    run_cmd git clone https://github.com/jasongin/nvs "$NVS_HOME"
    run_cmd bash "$NVS_HOME/nvs.sh" install
    run_cmd "$NVS_HOME/nvs.sh" add latest
    run_cmd "$NVS_HOME/nvs.sh" add lts
    run_cmd "$NVS_HOME/nvs.sh" link lts
}

install_miniconda() {
    if [ ! -d "$MINICONDA_DIR" ]; then
        log "Installing Miniconda3..."
        download_file https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh "$TMP_DIR/miniconda.sh"
        run_cmd bash "$TMP_DIR/miniconda.sh" -b -u -p "$MINICONDA_DIR"
        rm -f "$TMP_DIR/miniconda.sh"
        run_cmd "$MINICONDA_DIR/bin/conda" init bash
    else
        log "Miniconda3 is already installed."
    fi
}

setup_zsh() {
    log "Setting up ZSH..."
    run_cmd sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    run_cmd git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    run_cmd git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    run_cmd sed -i '/^plugins=(git/s/)$/ zsh-autosuggestions zsh-syntax-highlighting)/' "$USER_HOME/.zshrc"
    run_cmd sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="agnoster"/' "$USER_HOME/.zshrc"
    run_cmd sed -i '/^# ZSH_CUSTOM=/c\ZSH_CUSTOM='$ZSH_CUSTOM'' "$USER_HOME/.zshrc"
}

install_containerlab() {
    log "Installing Containerlab..."
    download_file https://raw.githubusercontent.com/srl-labs/containerlab/main/get.sh "$TMP_DIR/install-clab.sh"
    run_cmd chmod +x "$TMP_DIR/install-clab.sh"
    run_cmd sh "$TMP_DIR/install-clab.sh"
    rm -f "$TMP_DIR/install-clab.sh"
}

install_font() {
    log "Installing Cousine Nerd Font..."
    mkdir -p "$NERD_FONT_DIR"
    download_file https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Cousine.zip "$TMP_DIR/Cousine.zip"
    run_cmd unzip -o "$TMP_DIR/Cousine.zip" -d "$NERD_FONT_DIR"
    sudo rm -f "$TMP_DIR/Cousine.zip"
    run_cmd fc-cache -fv
}

cleanup() {
    log "Cleaning Up..."
    run_cmd sudo dnf autoremove -y
    run_cmd sudo dnf clean all
    rm -rf "$USER_HOME/.cache" "$TMP_DIR/*"
}

main() {
    check_prerequisites
    disable_selinux
    disable_firewall
    add_repositories
    install_packages
    install_nvs
    install_miniconda
    setup_zsh
    install_containerlab
    install_font
    cleanup
    log "Setup completed successfully."
}

main "$@"
