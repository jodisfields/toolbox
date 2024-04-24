#!/bin/bash

if [[ -f /etc/nobara-release ]]; then
  PKG_MANAGER="dnf"
elif [[ -f /etc/arch-release ]]; then
  PKG_MANAGER="pacman"
else
  echo "Unsupported Linux distribution"
  exit 1
fi

echo "Draining the node..."
kubectl drain $(hostname) --delete-local-data --force --ignore-daemonsets

echo "Stopping kubelet..."
sudo systemctl stop kubelet

echo "Disabling kubelet..."
sudo systemctl disable kubelet

echo "Resetting kubeadm..."
sudo kubeadm reset -f

# Remove packages using the determined package manager
if [ "$PKG_MANAGER" == "dnf" ]; then
  echo "Removing Kubernetes packages with DNF..."
  sudo dnf remove -y kubeadm kubectl kubelet kubernetes-cni
elif [ "$PKG_MANAGER" == "pacman" ]; then
  echo "Removing Kubernetes packages with Pacman..."
  sudo pacman -Rns --noconfirm kubeadm kubectl kubelet kubernetes-cni
fi

echo "Cleaning up remaining Kubernetes directories..."
sudo rm -rf ~/.kube
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/etcd/
sudo rm -rf /var/lib/kubelet/

echo "Kubernetes has been removed from your system."

