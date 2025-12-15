# Ceres Wheels

Custom Python wheels for ARM64 Linux, built via GitHub Actions.

## Quick Start

Install wheels directly from GitHub Releases:

```bash
# Rasterio (requires system GDAL)
apt-get install libgdal-dev
pip install https://github.com/ceresimaging/ceres-wheels/releases/download/rasterio-1.3.9-py3.12-arm64/rasterio-1.3.9-cp312-cp312-manylinux_2_39_aarch64.whl

# Fiona (requires system GDAL)
pip install https://github.com/ceresimaging/ceres-wheels/releases/download/fiona-1.10.1-py3.12-arm64/fiona-1.10.1-cp312-cp312-manylinux_2_39_aarch64.whl

# Timezonefinder (no system deps)
pip install https://github.com/ceresimaging/ceres-wheels/releases/download/timezonefinder-6.5.2-py3.12-arm64/timezonefinder-6.5.2-cp312-cp312-manylinux_2_39_aarch64.whl
```

## Available Packages

| Package | System Dependencies | Notes |
|---------|---------------------|-------|
| rasterio | `libgdal-dev` | Use `numpy<2` for rasterio 1.3.x |
| fiona | `libgdal-dev` | |
| timezonefinder | (none) | |
| pytorch | CUDA runtime | Manual build, see [pytorch/README.md](pytorch/README.md) |

## Building Wheels

### Generic Workflow (Recommended)

Use the generic workflow to build any package:

1. Go to [Actions → Build ARM64 Wheel](../../actions/workflows/build-wheel.yml)
2. Click "Run workflow"
3. Configure:
   - **Package**: e.g., `rasterio==1.3.9`, `fiona==1.10.1`, `timezonefinder==6.5.2`
   - **Python version**: 3.10, 3.11, or 3.12
   - **System deps**: apt packages needed (e.g., `libgdal-dev`), leave empty if none
   - **Publish**: `true` to create a GitHub Release
4. Wait for build (~2-5 min)
5. Download from artifacts or releases

### Rasterio-Specific Workflow

There's also a [rasterio-specific workflow](../../actions/workflows/build-rasterio-wheels.yml) with `numpy<2` handling for 1.3.x versions.

### PyTorch (Manual)

PyTorch requires manual builds on EC2. See [pytorch/README.md](pytorch/README.md).

## System Requirements

- **Architecture**: ARM64 (aarch64)
- **OS**: Ubuntu 24.04+ (glibc 2.39+)
- **Python**: 3.10, 3.11, or 3.12

## Repository Structure

```
ceres-wheels/
├── .github/workflows/
│   ├── build-wheel.yml            # Generic wheel builder
│   └── build-rasterio-wheels.yml  # Rasterio-specific
├── pytorch/
│   ├── README.md                  # PyTorch build guide
│   └── setup-ec2.sh               # EC2 setup script
├── rasterio/
│   └── README.md
└── README.md
```

## How It Works

```bash
# The workflow runs on GitHub's native ARM64 runner:
apt-get install -y libgdal-dev  # system deps if needed
pip wheel package==version --no-binary :all: -w /tmp/wheels/
auditwheel repair wheel.whl -w dist/ --plat manylinux_2_39_aarch64
```

## License

See [LICENSE](LICENSE) file.
