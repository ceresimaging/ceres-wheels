# Rasterio Wheels for ARM64 Linux

Pre-built rasterio wheels for ARM64 Linux (aarch64).

## Quick Start

### Building

1. Go to [Actions → Build Rasterio Wheels](../../actions/workflows/build-rasterio-wheels.yml)
2. Click "Run workflow"
3. Set rasterio version (e.g., `1.4.3`)
4. Set publish to `true` for release, `false` for testing
5. Download from artifacts or releases

### Installing

```bash
# From GitHub Release
pip install https://github.com/ceresimaging/ceres-wheels/releases/download/rasterio-1.4.3-arm64/rasterio-1.4.3-cp310-cp310-linux_aarch64.whl

# Requires system GDAL
apt-get install libgdal-dev  # or equivalent for your distro
```

## How It Works

The workflow runs on GitHub's native ARM64 runner (`ubuntu-24.04-arm`):

```bash
apt-get install -y libgdal-dev python3-dev
pip wheel rasterio==1.4.3 --no-binary rasterio -w dist/
```

That's it. `pip wheel` handles the Cython compilation.

## Requirements

- ARM64 Linux system
- System GDAL library installed
- Python 3.10

## Version Compatibility

| Rasterio | Python | Status |
|----------|--------|--------|
| 1.4.3 | 3.10 | ✅ Default |
| 1.3.9 | 3.10 | ✅ Tested |
