#!/bin/bash
set -e

#############################################################################
# EC2 Instance Setup for PyTorch ARM64 Wheel Building
#############################################################################
# For Ubuntu 22.04 ARM64 on m8g.8xlarge (or similar)
# No GPU required - just CUDA toolkit for cross-compilation
#############################################################################

echo "============================================================"
echo "PyTorch ARM64 Build Environment Setup"
echo "============================================================"

# Check architecture
ARCH=$(uname -m)
if [[ "${ARCH}" != "aarch64" ]]; then
    echo "ERROR: This script is for ARM64 (aarch64) only. Detected: ${ARCH}"
    exit 1
fi

# Add 32GB swap (safety margin for CUDA compilation)
echo ">>> Configuring 32GB swap..."
if [[ ! -f /swapfile ]]; then
    sudo fallocate -l 32G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi
free -h

# Install system dependencies
echo ">>> Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y wget software-properties-common build-essential \
    git cmake ninja-build libopenblas-dev libomp-dev libffi-dev libssl-dev \
    pkg-config libjpeg-dev libpng-dev unzip

# Install AWS CLI v2
echo ">>> Installing AWS CLI..."
curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# Install CUDA 12.6 toolkit + cuDNN
# Note: ubuntu2204/sbsa is for ARM64 (sbsa = server base system architecture)
echo ">>> Installing CUDA 12.6 toolkit and cuDNN..."
wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/sbsa/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
rm cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get install -y cuda-toolkit-12-6 libcudnn9-cuda-12 libcudnn9-dev-cuda-12

# Set CUDA environment
echo ">>> Configuring CUDA environment..."
if ! grep -q "CUDA_HOME" ~/.bashrc; then
    echo '' >> ~/.bashrc
    echo '# CUDA Configuration' >> ~/.bashrc
    echo 'export CUDA_HOME=/usr/local/cuda' >> ~/.bashrc
    echo 'export PATH=$CUDA_HOME/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}' >> ~/.bashrc
fi

export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}

# Python 3.10 dev packages + pip (Python 3.10 is preinstalled on Ubuntu 22.04)
echo ">>> Installing Python 3.10 development packages..."
sudo apt-get install -y python3.10-dev python3.10-venv
curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python3.10

# Python build dependencies
echo ">>> Installing Python build dependencies..."
python3.10 -m pip install --upgrade pip "setuptools<75.0.0" wheel
python3.10 -m pip install "packaging>=22.0,<24.0" "numpy<2.0" pyyaml typing_extensions cmake ninja \
    filelock sympy networkx jinja2 fsspec cffi pillow

echo ""
echo "============================================================"
echo "Setup complete!"
echo ""
echo "Run: source ~/.bashrc"
echo "Then verify with: nvcc --version && aws --version"
echo "============================================================"