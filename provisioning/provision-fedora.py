#!/usr/bin/env python

import subprocess

pkgs = [
    "1password",
    "alacritty",
    "ansible",
    "bridge-utils",
    "code-insiders",
    "containerd.io",
    "curl",
    "dnf-plugins-core",
    "docker-buildx-plugin",
    "docker-ce",
    "docker-ce-cli",
    "docker-compose-plugin",
    "firefox",
    "fzf",
    "gcc",
    "genisoimage",
    "gh",
    "git",
    "glibc",
    "gnome-shell-extension-common",
    "gnome-shell-extension-pop-shell",
    "gnome-shell-extension-pop-shell-shortcut-overrides",
    "gnome-tweaks",
    "graphviz",
    "iproute",
    "iputils",
    "koan",
    "libvirt",
    "libvirt-daemon",
    "neovim",
    "net-tools",
    "ngrep",
    "openssh-server",
    "openssl",
    "pykickstart",
    "python3",
    "qemu",
    "qemu-common",
    "qemu-img",
    "qemu-kvm",
    "qemu-tools",
    "redhat-rpm-config",
    "squashfs-tools",
    "syslinux",
    "tcpdump",
    "unzip",
    "util-linux-user",
    "vim",
    "virt-install",
    "virt-manager",
    "virt-manager-common",
    "wget",
    "which",
    "wireshark-cli",
    "xclip",
    "zsh",
    "zsh-autosuggestions",
    "zsh-syntax-highlighting",
]


def run_cmd(cmd):
    p = subprocess.Popen(
        cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    out, err = p.communicate()
    if not err:
        return out
    else:
        print("Error: ", err)


def install_packages():
    for pkg in pkgs:
        run_cmd(f"sudo dnf install -y {pkg}")
        print(f"{pkg} installed successfully.")


def main():
    install_packages()
    print("Packages installed successfully.")


if __name__ == "__main__":
    main()
