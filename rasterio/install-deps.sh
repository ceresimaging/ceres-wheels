#!/bin/bash
set -euo pipefail

#############################################################################
# System Dependencies for GDAL Build
#############################################################################
# Installs all required packages for building GDAL from source
# Designed for manylinux_2_28 containers (AlmaLinux 8 based, uses yum/dnf)
#############################################################################

echo "============================================================"
echo "Installing GDAL Build Dependencies"
echo "============================================================"

# Enable EPEL and PowerTools/CRB for additional packages
echo ">>> Enabling EPEL and PowerTools repositories..."
yum install -y epel-release
yum config-manager --set-enabled powertools || yum config-manager --set-enabled crb || true

# Update package lists
yum makecache

# Install build essentials and tools
echo ">>> Installing build tools..."
yum install -y \
    gcc \
    gcc-c++ \
    make \
    cmake \
    wget \
    ca-certificates \
    pkgconfig

# Geospatial libraries
echo ">>> Installing geospatial libraries..."
yum install -y \
    proj-devel \
    proj \
    geos-devel \
    sqlite-devel \
    libspatialite-devel

# Scientific data format libraries
echo ">>> Installing scientific format libraries..."
yum install -y \
    hdf5-devel \
    netcdf-devel

# Image format libraries
echo ">>> Installing image format libraries..."
yum install -y \
    libtiff-devel \
    libpng-devel \
    libjpeg-turbo-devel \
    libwebp-devel \
    giflib-devel \
    openjpeg2-devel

# Compression libraries
echo ">>> Installing compression libraries..."
yum install -y \
    zlib-devel \
    libzstd-devel \
    xz-devel

# libaec may not be available, skip if not found
yum install -y libaec-devel || echo "  libaec-devel not available, skipping"

# Network and security libraries
echo ">>> Installing network libraries..."
yum install -y \
    libcurl-devel \
    openssl-devel

# Additional dependencies
echo ">>> Installing additional dependencies..."
yum install -y \
    expat-devel \
    json-c-devel

# Clean up to reduce image size
echo ">>> Cleaning up..."
yum clean all
rm -rf /var/cache/yum

echo ""
echo "============================================================"
echo "Dependencies installed successfully!"
echo "============================================================"
