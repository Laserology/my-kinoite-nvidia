#!/bin/bash

set -ouex pipefail

# Install some base packages
dnf5 install -y tmux fastfetch

# Remove firefox in favour of using the flatpak
dnf5 remove -y firefox

# Install RPM-Fusion repos.
dnf5 -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf5 -y install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install Nvidia drivers & Cuda dependancies.
dnf5 -y install akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-cuda-libs

# Install container toolkit
dnf5 -y copr enable @ai-ml/nvidia-container-toolkit
dnf5 -y install nvidia-container-toolkit nvidia-container-toolkit-selinux
dnf5 -y copr disable @ai-ml/nvidia-container-toolkit
nvidia-ctk cdi generate -output /etc/cdi/nvidia.yaml

# Example for enabling a System Unit File
systemctl enable podman.socket
