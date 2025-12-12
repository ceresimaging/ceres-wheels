# Rasterio Wheels for ARM64 Linux

This directory contains build scripts and workflows for creating rasterio binary wheels for ARM64 Linux (aarch64) with manylinux compatibility.

## Overview

Official rasterio wheels from PyPI may not be available for all architectures. This build system creates portable, self-contained wheels for ARM64 Linux with GDAL bundled inside.

## Quick Start

### Building a Wheel

1. Navigate to the [Actions tab](../../actions)
2. Select "Build Rasterio Wheels" workflow
3. Click "Run workflow"
4. Configure build parameters:
   - **Rasterio version**: e.g., `1.3.9`
   - **GDAL version**: e.g., `3.6.4`
   - **Publish**: `false` for testing, `true` to create GitHub Release
5. Wait for build to complete (~60 minutes first time, ~15 minutes with cache)
6. Download wheel from workflow artifacts or GitHub Releases

### Installing a Wheel

```bash
# Download the wheel from GitHub Releases
pip install rasterio-1.3.9-cp310-cp310-manylinux_2_28_aarch64.whl

# Or install directly from URL
pip install https://github.com/ceresimaging/ceres-wheels/releases/download/rasterio-1.3.9_py310_gdal3.6.4_linux_aarch64/rasterio-1.3.9-cp310-cp310-manylinux_2_28_aarch64.whl
```

## Version Compatibility

| Rasterio | GDAL | Python | Status |
|----------|------|--------|--------|
| 1.3.9 | 3.6.4 | 3.10 | ✅ Tested |

## How It Works

### Build Process

1. **System Dependencies**: Installs PROJ, GEOS, HDF5, netCDF, image libraries via `install-deps.sh`
2. **GDAL Compilation**: Builds GDAL from source with all dependencies via `build-gdal.sh`
3. **Wheel Building**: Uses cibuildwheel with uv to build rasterio wheel
4. **Vendoring**: auditwheel copies GDAL + dependencies into wheel's `.libs` directory
5. **Result**: Self-contained ~50MB wheel that works on any manylinux_2_28 system

### What's Included

Each wheel contains:
- Rasterio Python package
- GDAL shared library (3.6.4)
- PROJ (9.0+)
- GEOS (3.11+)
- Format drivers: GeoTIFF, HDF5, netCDF, JPEG2000, PNG, JPEG, WebP
- Compression: zlib, zstd, lzma

**Total size**: ~50MB (compressed)

### Why Build from Source?

Official PyPI wheels may:
- Not support ARM64 architecture
- Use different GDAL versions
- Not include all format drivers you need

Building from source gives you:
- Control over GDAL version
- All drivers included
- Optimized for your target architecture
- No external GDAL dependency required

## Build Scripts

### `install-deps.sh`

Installs system packages needed for GDAL compilation:
- Geospatial: PROJ, GEOS, SQLite/SpatiaLite
- Formats: HDF5, netCDF, OpenJPEG2000
- Images: TIFF, PNG, JPEG, WebP, GIF
- Compression: zlib, zstd, lzma, aec
- Network: curl, OpenSSL

### `build-gdal.sh`

Compiles GDAL from source:
1. Checks if GDAL already installed (for caching)
2. Downloads GDAL source tarball from GitHub
3. Configures with CMake (static linking of dependencies)
4. Builds with all available CPU cores
5. Installs to `/usr/local`
6. Verifies installation

**Build time**: ~45 minutes (first run), 0 minutes (cached)

### `test-wheel.py`

Comprehensive wheel verification:
- Import test
- Version checks (rasterio, GDAL, PROJ)
- Driver availability
- Basic rasterio operations
- CRS transformations

Run after installing wheel:
```bash
python3 test-wheel.py
```

## Troubleshooting

### ImportError: libgdal.so not found

This shouldn't happen with properly built wheels. If it does, the wheel wasn't repaired correctly by auditwheel.

**Check vendored libraries**:
```bash
unzip -l rasterio-*.whl | grep libgdal
```

Should show `rasterio.libs/libgdal-*.so`.

### GDAL drivers missing

Check which drivers are available:
```python
from rasterio import drivers
print(drivers.raster_driver_extensions())
```

If drivers are missing, they weren't compiled into GDAL. Check `build-gdal.sh` CMake configuration.

### Wheel not compatible with manylinux_2_28

Your system might be older. Check glibc version:
```bash
ldd --version
```

Requires glibc 2.28 or newer (Ubuntu 22.04+, Debian 12+, Amazon Linux 2023+).

### Build timeout in GitHub Actions

GDAL compilation takes ~45 minutes. With QEMU emulation this could exceed 6 hours.

**Solution**: Use native ARM64 runners (`ubuntu-24.04-arm`) as configured in the workflow.

## Advanced Usage

### Building Locally

You can test the build scripts locally in a manylinux container:

```bash
# Pull manylinux_2_28 ARM64 image
docker pull quay.io/pypa/manylinux_2_28_aarch64

# Run container
docker run -it --rm \
  -v $(pwd):/workspace \
  quay.io/pypa/manylinux_2_28_aarch64 \
  bash

# Inside container
cd /workspace/rasterio
bash build-gdal.sh

# Build rasterio
/opt/python/cp310-cp310/bin/pip install build
/opt/python/cp310-cp310/bin/python -m build --wheel
```

### Customizing GDAL

Edit `build-gdal.sh` CMake configuration to:
- Enable/disable drivers
- Change optimization level
- Add custom GDAL plugins

Example - disable HDF5 driver:
```cmake
cmake .. \
  -DGDAL_ENABLE_HDF5=OFF \
  ...
```

### Multiple Python Versions

The workflow supports building for multiple Python versions via matrix strategy. Edit `.github/workflows/build-rasterio-wheels.yml`:

```yaml
strategy:
  matrix:
    python_version: ['3.10', '3.11', '3.12']
```

## Architecture

### Directory Structure

```
rasterio/
├── install-deps.sh      # System dependency installation
├── build-gdal.sh        # GDAL compilation from source
├── test-wheel.py        # Wheel verification tests
└── README.md            # This file
```

### Build Environment

- **Runner**: GitHub-hosted `ubuntu-24.04-arm` (free for public repos)
- **Container**: manylinux_2_28_aarch64 (AlmaLinux 8 based)
- **Tools**: cibuildwheel + uv for fast builds
- **Caching**: GDAL installation cached to reduce rebuild time

### Version Compatibility Matrix

Tested combinations:

| Rasterio | Python | GDAL | NumPy | Notes |
|----------|--------|------|-------|-------|
| 1.3.9 | 3.10 | 3.6.4 | <2.0 | ✅ Recommended |
| 1.3.9 | 3.11 | 3.6.4 | <2.0 | ⚠️ Untested |
| 1.4.x | 3.10 | 3.8+ | <2.0 | 📝 Future |

## Resources

- [Rasterio Documentation](https://rasterio.readthedocs.io/)
- [GDAL Documentation](https://gdal.org/)
- [cibuildwheel Documentation](https://cibuildwheel.pypa.io/)
- [manylinux Specification](https://github.com/pypa/manylinux)

## Contributing

To add support for new rasterio or GDAL versions:

1. Update version compatibility matrix in this README
2. Test build with new versions via workflow_dispatch
3. Verify wheel with `test-wheel.py`
4. Update version mapping if needed in workflow

## License

See [LICENSE](../LICENSE) in repository root.
