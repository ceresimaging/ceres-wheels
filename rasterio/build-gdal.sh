#!/bin/bash
set -euo pipefail

#############################################################################
# GDAL Build Script for Rasterio Wheels
#############################################################################
# Builds GDAL from source with all dependencies for rasterio compatibility
# Designed to run in manylinux_2_28 containers via cibuildwheel
#############################################################################

echo "============================================================"
echo "GDAL Build Script"
echo "============================================================"

# Configuration
GDAL_VERSION=${GDAL_VERSION:-3.6.4}
INSTALL_PREFIX=${INSTALL_PREFIX:-/usr/local}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "GDAL Version: ${GDAL_VERSION}"
echo "Install Prefix: ${INSTALL_PREFIX}"
echo ""

# Check if GDAL is already installed (for caching)
if command -v gdal-config &>/dev/null; then
    INSTALLED_VERSION=$(gdal-config --version)
    if [[ "${INSTALLED_VERSION}" == "${GDAL_VERSION}" ]]; then
        echo "✓ GDAL ${GDAL_VERSION} already installed, skipping build"
        echo "  Location: $(which gdal-config)"
        gdal-config --version
        exit 0
    else
        echo "⚠ Found GDAL ${INSTALLED_VERSION}, but need ${GDAL_VERSION}"
        echo "  Proceeding with build..."
    fi
fi

# Install system dependencies
echo ">>> Installing system dependencies..."
bash "${SCRIPT_DIR}/install-deps.sh"

# Download GDAL source
echo ">>> Downloading GDAL ${GDAL_VERSION}..."
GDAL_TARBALL="gdal-${GDAL_VERSION}.tar.gz"
GDAL_URL="https://github.com/OSGeo/gdal/releases/download/v${GDAL_VERSION}/${GDAL_TARBALL}"

wget -q --show-progress "${GDAL_URL}"
echo "✓ Downloaded ${GDAL_TARBALL}"

# Extract source
echo ">>> Extracting GDAL source..."
tar xzf "${GDAL_TARBALL}"
cd "gdal-${GDAL_VERSION}"
echo "✓ Extracted to gdal-${GDAL_VERSION}/"

# Configure with CMake
echo ">>> Configuring GDAL with CMake..."
mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_SHARED_LIBS=ON \
    -DGDAL_BUILD_OPTIONAL_DRIVERS=ON \
    -DGDAL_USE_INTERNAL_LIBS=ON \
    -DBUILD_PYTHON_BINDINGS=OFF \
    -DENABLE_IPO=ON

echo "✓ CMake configuration complete"

# Build GDAL
echo ">>> Building GDAL (this takes ~30-45 minutes)..."
NPROC=$(nproc)
echo "  Using ${NPROC} parallel jobs"
make -j"${NPROC}"
echo "✓ GDAL build complete"

# Install GDAL
echo ">>> Installing GDAL to ${INSTALL_PREFIX}..."
make install
echo "✓ GDAL installed"

# Update library cache
echo ">>> Updating library cache..."
ldconfig
echo "✓ Library cache updated"

# Verify installation
echo ""
echo "============================================================"
echo "GDAL Installation Verification"
echo "============================================================"

if ! command -v gdal-config &>/dev/null; then
    echo "ERROR: gdal-config not found in PATH"
    exit 1
fi

INSTALLED_VERSION=$(gdal-config --version)
if [[ "${INSTALLED_VERSION}" != "${GDAL_VERSION}" ]]; then
    echo "ERROR: Installed GDAL version (${INSTALLED_VERSION}) doesn't match expected (${GDAL_VERSION})"
    exit 1
fi

echo "✓ gdal-config:    $(which gdal-config)"
echo "✓ GDAL version:   ${INSTALLED_VERSION}"
echo "✓ GDAL prefix:    $(gdal-config --prefix)"
echo "✓ GDAL datadir:   $(gdal-config --datadir)"
echo ""
echo "============================================================"
echo "GDAL ${GDAL_VERSION} built and installed successfully!"
echo "============================================================"
