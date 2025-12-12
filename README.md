# Ceres Wheels

Custom Python wheels for architectures not available on PyPI.

This repository builds and distributes binary wheels for Python packages that lack official support for certain architectures, particularly ARM64 Linux systems used in cloud computing (AWS Graviton, Ampere, etc.).

## Available Packages

### 🔥 PyTorch

Custom PyTorch builds for ARM64 with T4G (sm_75) CUDA support for AWS g5g instances.

- **Status**: Manual builds, published to this Github Releases page
- **Documentation**: [pytorch/README.md](pytorch/README.md)
- **Target**: ARM64 + CUDA 12.6 + sm_75 support
- **Build Method**: Manual EC2 compilation

### 🗺️ Rasterio

Rasterio wheels for ARM64 Linux.

- **Status**: Automated GitHub Actions builds
- **Documentation**: [rasterio/README.md](rasterio/README.md)
- **Releases**: [GitHub Releases](../../releases)
- **Target**: ARM64 Linux
- **Build Method**: GitHub Actions (native ARM64 runner)

[![Build Rasterio Wheels](https://github.com/ceresimaging/ceres-wheels/actions/workflows/build-rasterio-wheels.yml/badge.svg)](https://github.com/ceresimaging/ceres-wheels/actions/workflows/build-rasterio-wheels.yml)

## Quick Start

### Rasterio

```bash
# Install system GDAL first
apt-get install libgdal-dev

# Install wheel from GitHub Release
pip install https://github.com/ceresimaging/ceres-wheels/releases/download/rasterio-1.4.3-arm64/rasterio-1.4.3-cp310-cp310-linux_aarch64.whl
```

### PyTorch

Follow the detailed manual build guide in [pytorch/README.md](pytorch/README.md).

## Why This Repository?

Many Python packages with C/C++ extensions don't provide pre-built wheels for ARM64 architecture:

- **Official PyPI**: Often focuses on x86_64 (AMD/Intel) platforms
- **ARM64 adoption**: Growing rapidly in cloud (AWS Graviton, GCP Tau T2A, Azure Cobalt)
- **Custom requirements**: Specific CUDA architectures, GDAL versions, etc.

This repository fills the gap by providing:

✅ **Optimized ARM64 builds** for cloud workloads
✅ **Self-contained wheels** with dependencies bundled
✅ **Verified compatibility** with manylinux standards
✅ **Automated builds** via GitHub Actions (where possible)

## Package Comparison

| Package | Architecture | Python | Publishing | Build Time | Automation |
|---------|--------------|--------|------------|------------|------------|
| PyTorch | ARM64 | 3.10 | GitHub Releases | 1.5-2 hrs | Manual |
| Rasterio | ARM64 | 3.10 | GitHub Releases | ~5 min | Automated |

## System Requirements

### Rasterio

- **OS**: Linux with system GDAL installed
- **Architecture**: ARM64 (aarch64)
- **Python**: 3.10

### PyTorch

- **OS**: Ubuntu 22.04 (for builds)
- **Architecture**: ARM64
- **Python**: 3.10
- **GPU**: NVIDIA T4G (sm_75) on AWS g5g instances

## Building Wheels

### Rasterio (Automated)

1. Go to [Actions → Build Rasterio Wheels](../../actions/workflows/build-rasterio-wheels.yml)
2. Click "Run workflow"
3. Configure:
   - Rasterio version (e.g., `1.4.3`)
   - Publish: `false` for testing, `true` for release
4. Wait for build (~5 min)
5. Download from artifacts or releases

### PyTorch (Manual)

See detailed instructions in [pytorch/README.md](pytorch/README.md).

## Repository Structure

```
ceres-wheels/
├── .github/
│   └── workflows/
│       └── build-rasterio-wheels.yml   # Rasterio build automation
├── pytorch/
│   ├── README.md                        # PyTorch build guide
│   └── setup-ec2.sh                     # EC2 setup script
├── rasterio/
│   └── README.md                        # Rasterio documentation
├── README.md                            # This file
└── LICENSE
```

## Technology Stack

### Rasterio Builds

- **CI/CD**: GitHub Actions (ubuntu-24.04-arm native runners)
- **Build**: `pip wheel --no-binary rasterio`
- **Dependencies**: System GDAL via apt

### PyTorch Builds

- **Platform**: AWS EC2 m8g.8xlarge (ARM64)
- **OS**: Ubuntu 22.04
- **CUDA**: 12.6 toolkit (no GPU needed for build)
- **Publishing**: AWS CodeArtifact

## FAQs

### Can I build for multiple Python versions?

Yes! Edit the workflow matrix:

```yaml
strategy:
  matrix:
    python: ['3.10', '3.11', '3.12']
```

### Can I build for x86_64 too?

Yes! Add to matrix:

```yaml
matrix:
  include:
    - arch: aarch64
      runner: ubuntu-24.04-arm
    - arch: x86_64
      runner: ubuntu-24.04
```

### What about macOS ARM64 (Apple Silicon)?

Possible, but requires:
- macOS runners (paid)
- Different dependency management (Homebrew)
- Separate workflow

Not currently supported, but PRs welcome!

## Contributing

Contributions are welcome! To add a new package:

1. Create `{package}/` directory
2. Add build scripts (`build-*.sh`, `install-deps.sh`)
3. Create `{package}/README.md` with documentation
4. Add GitHub Actions workflow in `.github/workflows/`
5. Test the build
6. Update this README

## Resources

- [PyPA: Python Packaging Authority](https://www.pypa.io/)
- [cibuildwheel Documentation](https://cibuildwheel.pypa.io/)
- [manylinux Specification](https://github.com/pypa/manylinux)
- [GitHub Actions ARM64 Runners](https://github.blog/changelog/2025-01-16-linux-arm64-hosted-runners-now-available-for-free-in-public-repositories-public-preview/)

## License

See [LICENSE](LICENSE) file.

## Support

For issues:
- **Package-specific**: See individual package READMEs
- **Build system**: Open an issue in this repository
- **General**: Refer to official package documentation

---

**Note**: These wheels are provided for convenience. Always verify wheels before use in production and prefer official PyPI packages when available.
