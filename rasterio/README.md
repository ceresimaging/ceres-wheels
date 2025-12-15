# Rasterio Wheels for ARM64 Linux

Pre-built rasterio wheels for ARM64 Linux (aarch64).

## Installation

```bash
# Requires system GDAL
apt-get install libgdal-dev

# Install from GitHub Release
pip install https://github.com/ceresimaging/ceres-wheels/releases/download/rasterio-1.3.9-py3.12-arm64/rasterio-1.3.9-cp312-cp312-manylinux_2_39_aarch64.whl

# For rasterio 1.3.x, also need numpy<2
pip install "numpy<2"
```

## Building

Use either workflow:

1. **Generic**: [Actions → Build ARM64 Wheel](../../actions/workflows/build-wheel.yml)
   - Package: `rasterio==1.3.9`
   - System deps: `libgdal-dev`

2. **Rasterio-specific**: [Actions → Build Rasterio Wheels](../../actions/workflows/build-rasterio-wheels.yml)
   - Has built-in `numpy<2` handling for 1.3.x versions

## Requirements

- ARM64 Linux (Ubuntu 24.04+ / glibc 2.39+)
- System GDAL installed
- Python 3.10, 3.11, or 3.12
- `numpy<2` for rasterio 1.3.x
