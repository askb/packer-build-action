#!/bin/bash
# Baseline provisioning script for Ubuntu images
# SPDX-License-Identifier: Apache-2.0

set -eux -o pipefail

echo "========================================="
echo "Baseline Provisioning Script"
echo "Distribution: ${DISTRO:-unknown}"
echo "========================================="

# Update package lists
echo "Updating package lists..."
sudo apt-get update

# Install essential packages
echo "Installing essential packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Python and pip
echo "Installing Python..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv

# Install common development tools
echo "Installing development tools..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    make \
    gcc \
    g++ \
    automake \
    autoconf \
    pkg-config

# Install monitoring tools
echo "Installing monitoring tools..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sysstat \
    iotop \
    iftop \
    tcpdump

# Configure timezone
echo "Configuring timezone..."
sudo timedatectl set-timezone UTC || true

# Enable NTP time synchronization
echo "Enabling NTP..."
sudo timedatectl set-ntp on || true

# Configure sysctl for performance
echo "Configuring sysctl..."
sudo tee /etc/sysctl.d/99-performance.conf > /dev/null <<EOF
# Network performance tuning
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Connection tracking
net.netfilter.nf_conntrack_max = 1048576
net.nf_conntrack_max = 1048576

# File handles
fs.file-max = 2097152
EOF

# Apply sysctl changes (or skip if it fails)
sudo sysctl -p /etc/sysctl.d/99-performance.conf || true

# Configure limits
echo "Configuring system limits..."
sudo tee /etc/security/limits.d/99-custom.conf > /dev/null <<EOF
*    soft nofile 65536
*    hard nofile 65536
*    soft nproc  65536
*    hard nproc  65536
EOF

# Disable unnecessary services
echo "Disabling unnecessary services..."
for service in apport snapd.seeded; do
    sudo systemctl disable $service || true
    sudo systemctl stop $service || true
done

# Clean up package cache
echo "Cleaning up..."
sudo apt-get autoremove -y
sudo apt-get clean

echo "========================================="
echo "Baseline provisioning completed"
echo "========================================="
