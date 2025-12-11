#!/usr/bin/env python3
"""
Rasterio Wheel Verification Script

Tests that a rasterio wheel is properly built with GDAL vendored correctly.
This script should be run after installing the wheel to verify functionality.
"""

import sys
import platform


def test_import():
    """Test that rasterio can be imported."""
    print("=" * 60)
    print("Test 1: Import rasterio")
    print("=" * 60)
    try:
        import rasterio
        print(f"✓ rasterio imported successfully")
        print(f"  Version: {rasterio.__version__}")
        return True
    except ImportError as e:
        print(f"✗ Failed to import rasterio: {e}")
        return False


def test_versions():
    """Test that GDAL and PROJ versions are accessible."""
    print("\n" + "=" * 60)
    print("Test 2: Check GDAL and PROJ versions")
    print("=" * 60)
    try:
        import rasterio

        gdal_version = rasterio.__gdal_version__
        print(f"✓ GDAL version: {gdal_version}")

        try:
            proj_version = rasterio.__proj_version__
            print(f"✓ PROJ version: {proj_version}")
        except AttributeError:
            # Older rasterio versions might not have this
            print("  PROJ version attribute not available (older rasterio)")

        return True
    except Exception as e:
        print(f"✗ Failed to get version info: {e}")
        return False


def test_gdal_drivers():
    """Test that critical GDAL drivers are available."""
    print("\n" + "=" * 60)
    print("Test 3: Verify GDAL drivers")
    print("=" * 60)
    try:
        from rasterio import drivers

        # Get all available drivers
        raster_drivers = set(drivers.raster_driver_extensions().keys())

        # Critical drivers that should be present
        required_drivers = {
            'GTiff',     # GeoTIFF (essential)
            'HDF5',      # HDF5 format
            'netCDF',    # NetCDF format
            'PNG',       # PNG images
            'JPEG',      # JPEG images
            'GeoJSON',   # GeoJSON
        }

        # Optional but useful drivers
        optional_drivers = {
            'GPKG',         # GeoPackage
            'JP2OpenJPEG',  # JPEG2000
        }

        # Check required drivers
        missing = required_drivers - raster_drivers
        if missing:
            print(f"✗ Missing required drivers: {missing}")
            return False

        print(f"✓ All required drivers present")
        for driver in sorted(required_drivers):
            print(f"  - {driver}")

        # Check optional drivers
        present_optional = optional_drivers & raster_drivers
        if present_optional:
            print(f"\n✓ Optional drivers present:")
            for driver in sorted(present_optional):
                print(f"  - {driver}")

        missing_optional = optional_drivers - raster_drivers
        if missing_optional:
            print(f"\n  Missing optional drivers: {missing_optional}")

        return True
    except Exception as e:
        print(f"✗ Failed to check drivers: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_basic_functionality():
    """Test basic rasterio functionality."""
    print("\n" + "=" * 60)
    print("Test 4: Basic functionality")
    print("=" * 60)
    try:
        import rasterio
        from rasterio.io import MemoryFile
        import numpy as np

        # Create an in-memory GeoTIFF
        with MemoryFile() as memfile:
            with memfile.open(
                driver='GTiff',
                height=10,
                width=10,
                count=1,
                dtype='uint8',
                crs='EPSG:4326',
                transform=rasterio.transform.from_bounds(0, 0, 1, 1, 10, 10)
            ) as dataset:
                # Write some data
                data = np.arange(100, dtype='uint8').reshape(10, 10)
                dataset.write(data, 1)

                print(f"✓ Created in-memory raster")
                print(f"  Shape: {dataset.shape}")
                print(f"  CRS: {dataset.crs}")
                print(f"  Driver: {dataset.driver}")

        print(f"✓ Basic rasterio operations successful")
        return True
    except Exception as e:
        print(f"✗ Failed basic functionality test: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_crs_operations():
    """Test CRS and projection operations."""
    print("\n" + "=" * 60)
    print("Test 5: CRS operations")
    print("=" * 60)
    try:
        from rasterio.crs import CRS

        # Test creating CRS from EPSG
        crs = CRS.from_epsg(4326)
        print(f"✓ Created CRS from EPSG:4326")
        print(f"  CRS: {crs}")

        # Test proj4 string
        proj4 = crs.to_proj4()
        if '+proj=longlat' in proj4 and '+datum=WGS84' in proj4:
            print(f"✓ PROJ4 string correct: {proj4}")
        else:
            print(f"✗ Unexpected PROJ4 string: {proj4}")
            return False

        return True
    except Exception as e:
        print(f"✗ Failed CRS operations: {e}")
        import traceback
        traceback.print_exc()
        return False


def print_system_info():
    """Print system information."""
    print("\n" + "=" * 60)
    print("System Information")
    print("=" * 60)
    print(f"Architecture: {platform.machine()}")
    print(f"Platform: {platform.platform()}")
    print(f"Python version: {sys.version}")

    try:
        import numpy as np
        print(f"NumPy version: {np.__version__}")
    except ImportError:
        print("NumPy: not installed")


def main():
    """Run all tests."""
    print("\nRasterio Wheel Verification")
    print_system_info()

    tests = [
        test_import,
        test_versions,
        test_gdal_drivers,
        test_basic_functionality,
        test_crs_operations,
    ]

    results = []
    for test in tests:
        try:
            result = test()
            results.append(result)
        except Exception as e:
            print(f"\n✗ Test failed with exception: {e}")
            import traceback
            traceback.print_exc()
            results.append(False)

    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    passed = sum(results)
    total = len(results)
    print(f"Passed: {passed}/{total}")

    if all(results):
        print("\n✓ All tests passed!")
        return 0
    else:
        print("\n✗ Some tests failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
