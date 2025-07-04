#!/bin/bash

set -ouex pipefail

# mitigate upstream packaging bug: https://bugzilla.redhat.com/show_bug.cgi?id=2332429
# swap the incorrectly installed OpenCL-ICD-Loader for ocl-icd, the expected package
dnf5 -y swap --repo='fedora' OpenCL-ICD-Loader ocl-icd

# Install RPM-Fusion repos.
dnf5 -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Enable some repositories.
dnf5 -y copr enable @ai-ml/nvidia-container-toolkit
dnf5 -y copr enable kylegospo/oversteer
dnf5 -y copr enable ublue-os/packages
dnf5 -y copr enable ublue-os/staging

# Install Nvidia drivers, Cuda dependancies & Container Toolkit.
dnf5 -y install akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-cuda-libs nvidia-settings
dnf5 -y install nvidia-container-toolkit nvidia-container-toolkit-selinux

# Misc package config.
dnf5 install -y ublue-os-udev-rules ublue-os-update-services ublue-os-signing ublue-os-luks fedora-repos-archive zstd tmux fastfetch supergfxctl-plasmoid supergfxctl
dnf5 remove -y firefox # In favor of flatpak

# Remove now-unused copr repos.
dnf5 -y copr disable @ai-ml/nvidia-container-toolkit
dnf5 -y copr disable kylegospo/oversteer
dnf5 -y copr disable ublue-os/packages
dnf5 -y copr disable ublue-os/staging

# Prevent partial QT upgrades that may break SDDM/KWin
dnf5 versionlock add "qt6-*"

# Use Signed Kernel and Versionlock
for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra; do
    rpm --erase $pkg --nodeps
done

# Example system services.
systemctl enable podman.socket

# Verify VERY IMPORTANT packages are installed.
source /etc/os-release

IMPORTANT_PACKAGES=(
    systemd
    pipewire
    wireplumber
    kwin
    plasma-desktop
    sddm
)

for package in "${IMPORTANT_PACKAGES[@]}"; do
    rpm -q "$package" > /dev/null || { echo "Missing package: $package... Exiting"; exit 1 ; }
done

systemctl enable ublue-nvctk-cdi.service

# use CoreOS' generator for emergency/rescue boot
# see detail: https://github.com/ublue-os/main/issues/653
CSFG=/usr/lib/systemd/system-generators/coreos-sulogin-force-generator
curl -sSLo ${CSFG} https://raw.githubusercontent.com/coreos/fedora-coreos-config/refs/heads/stable/overlay.d/05core/usr/lib/systemd/system-generators/coreos-sulogin-force-generator
chmod +x ${CSFG}

# Ensure Initramfs is generated
KERNEL_VERSION="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"
