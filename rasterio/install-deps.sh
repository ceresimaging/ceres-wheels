#!/bin/bash
set -euo pipefail

#############################################################################
# System Dependencies for GDAL Build
#############################################################################
# Installs all required packages for building GDAL from source
# Designed for manylinux_2_28 containers (Ubuntu 22.04 based)
#############################################################################

echo "============================================================"
echo "Installing GDAL Build Dependencies"
echo "============================================================"

# Update package lists
apt-get update

# Install build essentials and tools
echo ">>> Installing build tools..."
apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    wget \
    ca-certificates \
    pkg-config

# Geospatial libraries
echo ">>> Installing geospatial libraries..."
apt-get install -y --no-install-recommends \
    libproj-dev \
    proj-data \
    proj-bin \
    libgeos-dev \
    libsqlite3-dev \
    libspatialite-dev

# Scientific data format libraries
echo ">>> Installing scientific format libraries..."
apt-get install -y --no-install-recommends \
    libhdf5-dev \
    libnetcdf-dev

# Image format libraries
echo ">>> Installing image format libraries..."
apt-get install -y --no-install-recommends \
    libtiff-dev \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    libgif-dev \
    libopenjp2-7-dev

# Compression libraries
echo ">>> Installing compression libraries..."
apt-get install -y --no-install-recommends \
    zlib1g-dev \
    libzstd-dev \
    liblzma-dev \
    libaec-dev

# Network and security libraries
echo ">>> Installing network libraries..."
apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev

# Additional dependencies
echo ">>> Installing additional dependencies..."
apt-get install -y --no-install-recommends \
    libexpat1-dev \
    libjson-c-dev

# Clean up to reduce image size
echo ">>> Cleaning up..."
apt-get clean
rm -rf /var/lib/apt/lists/*

echo ""
echo "============================================================"
echo "Dependencies installed successfully!"
echo "============================================================"
