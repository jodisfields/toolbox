#!/usr/bin/env python3

import subprocess
import logging
import os

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

# Initialize logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)

pkgs = [
    # List of packages
    "1password",
    "alacritty",
    "ansible",  # trimmed for brevity
]


def run_cmd(cmd, env=None):
    """
    Run a shell command in a subprocess, capturing stdout and stderr.

    Args:
        cmd (list): Command and arguments to run.
        env (dict): Environment variables to set.

    Returns:
        stdout (str): Standard output of the command.
    """
    try:
        p = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
            env=env,
        )
        return p.stdout
    except subprocess.CalledProcessError as e:
        logging.error(f"Command '{' '.join(e.cmd)}' failed with error: {e.stderr}")
        return None


def install_packages():
    """
    Install packages using dnf.
    """
    # Construct the dnf install command
    cmd = ["sudo", "dnf", "install", "-y"] + pkgs
    logging.info("Installing packages...")
    run_cmd(cmd)
    logging.info("Packages installed successfully.")


def setup_zsh():
    """
    Set up Zsh and related plugins.
    """
    user_home = os.path.expanduser("~")
    zsh_custom = os.environ.get("ZSH_CUSTOM", f"{user_home}/.oh-my-zsh/custom")

    # Ensure ZSH_CUSTOM is exported for commands that depend on it
    env = os.environ.copy()
    env["ZSH_CUSTOM"] = zsh_custom

    run_cmd(
        [
            "sh",
            "-c",
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)",
        ],
        env=env,
    )
    run_cmd(
        [
            "git",
            "clone",
            "https://github.com/zsh-users/zsh-autosuggestions",
            f"{zsh_custom}/plugins/zsh-autosuggestions",
        ],
        env=env,
    )
    run_cmd(
        [
            "git",
            "clone",
            "https://github.com/zsh-users/zsh-syntax-highlighting.git",
            f"{zsh_custom}/plugins/zsh-syntax-highlighting",
        ],
        env=env,
    )

    zshrc_path = os.path.join(user_home, ".zshrc")
    with open(zshrc_path, "r+") as f:
        content = f.read()
        content = content.replace(
            "plugins=(git)", "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)"
        )
        content = content.replace('ZSH_THEME="robbyrussell"', 'ZSH_THEME="agnoster"')
        f.seek(0)
        f.write(content)
        f.truncate()

    logging.info("Zsh setup completed.")


def main():
    install_packages()
    setup_zsh()


if __name__ == "__main__":
    main()
