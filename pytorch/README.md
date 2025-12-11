# Building PyTorch 2.9.1 for ARM64 with T4G (sm_75) Support

This guide builds a PyTorch wheel for ARM64 with CUDA 12.6 and sm_75 support for NVIDIA T4G GPUs (AWS g5g instances).

## Table of Contents

- [Why This Is Needed](#why-this-is-needed)
- [Prerequisites](#prerequisites)
- [Step 1: Launch EC2 Instance](#step-1-launch-ec2-instance)
- [Step 2: Run Setup Script](#step-2-run-setup-script)
- [Step 3: Clone PyTorch](#step-3-clone-pytorch)
- [Step 4: Build PyTorch](#step-4-build-pytorch)
- [Step 5: Verify the Wheel](#step-5-verify-the-wheel)
- [Step 6: Upload to GitHub Releases](#step-6-upload-to-github-releases)
- [Step 7: Test on g5g Instance (Optional)](#step-7-test-on-g5g-instance-optional)
- [Using in Docker](#using-in-docker)
  - [Testing the Container](#testing-the-container)
- [Troubleshooting](#troubleshooting)
- [Wheel Size Notes](#wheel-size-notes)

## Why This Is Needed

NVIDIA's official PyTorch ARM64 wheels only include sm_80 and sm_90 architectures, excluding sm_75 (Turing/T4G). This causes PyTorch to fall back to CPU on g5g instances.

## Prerequisites

- AWS account with CodeArtifact access
- EC2 instance: **m8g.8xlarge** (32 vCPU, 128GB RAM) with **Ubuntu 22.04 ARM64**
- ~150GB EBS storage

> **Important:** Build on Ubuntu 22.04 for glibc compatibility. Wheels built on 24.04 won't work on 22.04 containers.

## Step 1: Launch EC2 Instance

Launch an `m8g.8xlarge` with Ubuntu 22.04 ARM64 AMI and 150GB gp3 root volume.

## Step 2: Run Setup Script

Create `setup-ec2.sh`:

```bash
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
```

Run it:
```bash
chmod +x setup-ec2.sh
./setup-ec2.sh
source ~/.bashrc
```

Verify:
```bash
nvcc --version       # Should show CUDA 12.6
python3.10 --version # Should show 3.10.x
aws --version        # Should show aws-cli/2.x.x
free -h              # Should show 32GB swap
```

## Step 3: Clone PyTorch

```bash
cd ~
git clone --recursive --depth 1 --branch v2.9.1 https://github.com/pytorch/pytorch.git
cd pytorch
git submodule sync
git submodule update --init --recursive --depth 1
python3.10 -m pip install -r requirements.txt
```

## Step 4: Build PyTorch

```bash
cd ~/pytorch

# CUDA compiler settings (required when building without GPU)
export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}
export CUDACXX=/usr/local/cuda/bin/nvcc
export CMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
export CUDAHOSTCXX=/usr/bin/g++

# Strip debug symbols from compiled libraries (reduces wheel size significantly)
export CFLAGS="-g0"
export CXXFLAGS="-g0"

#############################################################################
# CUDA Architecture Selection
#############################################################################
# Each architecture adds ~100-150MB to the wheel. Choose based on your needs:
#
# T4G only (g5g instances) - smallest wheel (~300MB):
#   TORCH_CUDA_ARCH_LIST="7.5"
#
# T4G + forward compatibility via PTX JIT (~350MB):
#   TORCH_CUDA_ARCH_LIST="7.5;8.0+PTX"
#   (PTX code is JIT-compiled at runtime for newer GPUs - slower first run)
#
# T4G + A10G/A100 + H100 - covers most AWS GPU instances (~450MB):
#   TORCH_CUDA_ARCH_LIST="7.5;8.0;9.0"
#
# All architectures - maximum compatibility (~650MB):
#   TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0"
#
# For reference, upstream ARM64 wheels only include: sm_80, sm_90
#############################################################################
export TORCH_CUDA_ARCH_LIST="7.5"
export CUDAARCHS="75"
export CMAKE_CUDA_ARCHITECTURES="75"

# PyTorch build configuration
export USE_CUDA=1 USE_CUDNN=1 USE_NCCL=1 USE_DISTRIBUTED=1
export USE_MKLDNN=0 USE_QNNPACK=1 USE_PYTORCH_QNNPACK=1 USE_XNNPACK=1
export USE_FBGEMM=0 USE_KINETO=1 FORCE_CUDA=1 BUILD_TEST=0
export CMAKE_GENERATOR=Ninja

# ARM64 optimization
export USE_PRIORITIZED_TEXT_FOR_LD=1

# Parallel jobs (adjust based on RAM: ~4GB per job for CUDA compilation)
export MAX_JOBS=24

# Build (takes 1.5-2 hours for single architecture)
python3.10 setup.py bdist_wheel 2>&1 | tee ~/pytorch-build.log
```

## Step 5: Verify the Wheel

```bash
# Check wheel was created
ls -lh ~/pytorch/dist/*.whl

# Extract and verify sm_75 is included
rm -rf /tmp/torch-wheel && mkdir -p /tmp/torch-wheel
unzip -q ~/pytorch/dist/torch*.whl -d /tmp/torch-wheel
cuobjdump /tmp/torch-wheel/torch/lib/libtorch_cuda.so --list-elf 2>/dev/null | grep sm_75 | head -3

# Quick import test (won't test GPU without hardware)
cd ~
python3.10 -m venv ~/test-venv
source ~/test-venv/bin/activate
pip install ~/pytorch/dist/torch*.whl "numpy<2.0"
python3.10 -c "import torch; print(f'PyTorch {torch.__version__}, CUDA {torch.version.cuda}, Archs: {torch.cuda.get_arch_list()}')"
deactivate
```

## Step 6: Upload to GitHub Releases

GitHub Packages doesn't support PyPI wheels well, so we'll use GitHub Releases instead. This makes the wheel publicly downloadable.

```bash
# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update && sudo apt-get install -y gh

# Authenticate with GitHub
gh auth login

# Rename wheel to simpler filename and create release
cd ~/pytorch/dist
ORIGINAL_WHEEL=$(ls torch*.whl)
# We'll follow the naming convention of official PyTorch wheels
# See https://download.pytorch.org/whl/torch/
SIMPLE_WHEEL="torch-2.9.1+cu126-cp310-cp310-manylinux_2_35_aarch64.whl"
cp "$ORIGINAL_WHEEL" "$SIMPLE_WHEEL"

gh release create "pytorch-2.9.1-arm64-sm75" \
    --repo ceresimaging/ceres-wheels \
    --title "PyTorch 2.9.1 ARM64 + CUDA 12.6 + sm_75" \
    --notes "PyTorch wheel for ARM64 with NVIDIA T4G (sm_75) support, for use on AWS g5g instances.

Built on Ubuntu 22.04 (Glibc 2.35) with:
- Python 3.10
- CUDA 12.6
- cuDNN 9
- SM architecture: 7.5 (T4G)

Install with:
\`\`\`bash
pip install https://github.com/ceresimaging/ceres-wheels/releases/download/pytorch-2.9.1-arm64-sm75/torch-2.9.1+cu126-cp310-cp310-manylinux_2_35_aarch64.whl
\`\`\`

Remember to also install \`numpy<2.0\` and CUDA runtime as dependencies. See the README for details.
" \
    "$SIMPLE_WHEEL"
```

### Installing from GitHub Releases

```bash
# Direct install
pip install https://github.com/ceresimaging/ceres-wheels/releases/download/pytorch-2.9.1-arm64-sm75/torch-2.9.1+cu126-cp310-cp310-manylinux_2_35_aarch64.whl

# Or download first
wget https://github.com/ceresimaging/ceres-wheels/releases/download/pytorch-2.9.1-arm64-sm75/torch-2.9.1+cu126-cp310-cp310-manylinux_2_35_aarch64.whl
pip install torch-2.9.1+cu126-cp310-cp310-manylinux_2_35_aarch64.whl
```

## Step 7: Test on g5g Instance (Optional)

```bash
# On a g5g instance with GPU
pip install https://github.com/ceresimaging/ceres-wheels/releases/download/pytorch-2.9.1-arm64-sm75/torch-2.9.1+cu126-cp310-cp310-manylinux_2_35_aarch64.whl
pip install "numpy<2.0"

python3 -c "
import torch
print(f'CUDA available: {torch.cuda.is_available()}')
print(f'GPU: {torch.cuda.get_device_name(0)}')
print(f'Archs: {torch.cuda.get_arch_list()}')
x = torch.randn(1000, 1000, device='cuda')
print('GPU compute: OK')
"
```

## Using in Docker

ARM64 and x86_64 PyTorch wheels handle CUDA libraries differently:

| Architecture | Wheel Size | CUDA Libraries | Docker Requires |
|--------------|------------|----------------|-----------------|
| x86_64 | ~800MB | Bundled inside wheel (statically linked) | Nothing extra |
| ARM64 | ~185-300MB | Dynamically linked to system | CUDA runtime in image |

**Why the difference?** NVIDIA/PyTorch made the x86_64 wheels self-contained for maximum portability, while ARM64 wheels expect CUDA to be installed on the system. This is an upstream decision, not specific to our custom wheel.

**Practical impact:** For x86_64 GPU containers, you only need the `nvidia-container-toolkit` which mounts the GPU driver. For ARM64 GPU containers, you must also install CUDA runtime libraries in the image:

```dockerfile
# Add CUDA runtime for ARM64 GPU builds
ARG INSTALL_CUDA_RUNTIME="false"
RUN if [ "$INSTALL_CUDA_RUNTIME" = "true" ]; then \
        apt-get update && \
        apt-get install -y --no-install-recommends wget ca-certificates && \
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/sbsa/cuda-keyring_1.1-1_all.deb && \
        dpkg -i cuda-keyring_1.1-1_all.deb && \
        rm cuda-keyring_1.1-1_all.deb && \
        apt-get update && \
        apt-get install -y --no-install-recommends \
            cuda-cudart-12-6 \
            libcublas-12-6 \
            libcufft-12-6 \
            libcurand-12-6 \
            libcusparse-12-6 \
            libcusolver-12-6 \
            libnvjitlink-12-6 \
            libcudnn9-cuda-12 \
            libnccl2 \
            libopenblas0 \
            libcufile-12-6 \
            cuda-cupti-12-6 && \
        rm -rf /var/lib/apt/lists/* && \
        ldconfig; \
    fi

ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}
```

Build with: `docker build --build-arg INSTALL_CUDA_RUNTIME=true -t myapp:arm64-gpu .`

### Testing the Container

Create `test_cuda.py`:

```python
import platform
import sys

print(f"Architecture: {platform.machine()}")
print(f"Platform: {platform.platform()}")
print(f"Python version: {sys.version}")

try:
    import numpy as np
    print(f"NumPy version: {np.__version__}")
except ImportError:
    print("NumPy: not installed")

try:
    import torch
    print(f"\nPyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    print(f"CUDA version (torch): {torch.version.cuda}")
    print(f"cuDNN version: {torch.backends.cudnn.version()}")
    print(f"cuDNN enabled: {torch.backends.cudnn.enabled}")
    print(f"Supported SM archs: {torch.cuda.get_arch_list()}")
    
    if torch.cuda.is_available():
        print(f"\nGPU count: {torch.cuda.device_count()}")
        print(f"GPU name: {torch.cuda.get_device_name(0)}")
        print(f"GPU compute capability: {torch.cuda.get_device_capability(0)}")
        
        # Memory info
        props = torch.cuda.get_device_properties(0)
        print(f"GPU memory: {props.total_memory / 1024**3:.1f} GB")
        print(f"GPU multi-processors: {props.multi_processor_count}")
        
        # Quick GPU test
        x = torch.randn(1000, 1000).cuda()
        y = torch.matmul(x, x)
        torch.cuda.synchronize()
        print("\nGPU tensor operation: SUCCESS")
    else:
        print("\n⚠️  CUDA NOT AVAILABLE - falling back to CPU!")
        
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
```

Run it in the container:

```bash
# On a g5g instance with nvidia-container-toolkit installed
docker run --rm --gpus all myapp:arm64-gpu python3 test_cuda.py
```

Expected output:

```
Architecture: aarch64
Platform: Linux-...-aarch64-with-glibc2.35
Python version: 3.10.x
NumPy version: 1.x.x

PyTorch version: 2.9.1a0+gitd38164a
CUDA available: True
CUDA version (torch): 12.6
cuDNN version: 90100
cuDNN enabled: True
Supported SM archs: ['sm_75']

GPU count: 1
GPU name: NVIDIA T4G
GPU compute capability: (7, 5)
GPU memory: 16.0 GB
GPU multi-processors: 40

GPU tensor operation: SUCCESS
```

> **Note:** PyTorch internally reports the full version with git hash (`2.9.1a0+gitd38164a`), even though the wheel filename is simplified.

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `GLIBC_2.38 not found` | Built on Ubuntu 24.04 | Rebuild on Ubuntu 22.04 |
| `libcublas.so not found` | Missing CUDA runtime | Add CUDA libs to Dockerfile |
| `sm_75 is not compatible` | Using upstream wheel | Use this custom wheel |
| OOM during build | Too many parallel jobs | Reduce `MAX_JOBS` to 8-12, ensure swap is enabled |
| `CMAKE_CUDA_COMPILER not found` | PATH not set | Run `source ~/.bashrc` or export CUDA vars |
| Build killed by kernel | Out of memory | Add swap: `sudo fallocate -l 32G /swapfile` |
| `canonicalize_version() got an unexpected keyword argument` | setuptools/packaging version mismatch | `pip install "setuptools<75.0.0" "packaging>=22.0,<24.0"` |

## Wheel Size Notes

With `TORCH_CUDA_ARCH_LIST="7.5"` and debug symbols stripped (`CFLAGS="-g0"`), the wheel is ~185MB.

Each additional architecture adds ~150-180MB:

| Configuration | Architectures | Approx Size |
|---------------|---------------|-------------|
| T4G only | sm_75 | ~185MB |
| T4G + PTX | sm_75, 8.0+PTX | ~250MB |
| Multi-GPU | sm_75, sm_80, sm_90 | ~550MB |
| All archs | sm_75, sm_80, sm_86, sm_89, sm_90 | ~900MB |

Upstream ARM64 wheels only include sm_80 and sm_90 (~300MB).