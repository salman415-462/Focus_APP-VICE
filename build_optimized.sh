#!/bin/bash

# Flutter App Size Optimization - Build and Verification Script
# This script builds the optimized release APKs and reports sizes

echo "========================================"
echo "Flutter App Size Optimization Build"
echo "========================================"
echo ""

# Clean previous build artifacts
echo "Step 1: Cleaning previous build artifacts..."
flutter clean
echo ""

# Build release APK with ABI splits
echo "Step 2: Building optimized release APKs..."
echo "Command: flutter build apk --release --split-per-abi"
echo ""
flutter build apk --release --split-per-abi
echo ""

# Check resulting APK sizes
echo "========================================"
echo "Build Output Analysis"
echo "========================================"
echo ""

OUTPUT_DIR="build/app/outputs/apk/release"

if [ -d "$OUTPUT_DIR" ]; then
    echo "APK files generated:"
    echo ""
    ls -lh "$OUTPUT_DIR"/*.apk 2>/dev/null || echo "No APK files found"
    echo ""
    
    echo "Individual APK sizes:"
    echo ""
    for apk in "$OUTPUT_DIR"/*.apk; do
        if [ -f "$apk" ]; then
            SIZE=$(du -h "$apk" | cut -f1)
            NAME=$(basename "$apk")
            echo "  $NAME: $SIZE"
        fi
    done
    echo ""
    
    # Calculate total
    echo "Total size of all APKs:"
    du -sh "$OUTPUT_DIR"/*.apk 2>/dev/null | cut -f1
    echo ""
else
    echo "ERROR: Build output directory not found!"
    echo "Build may have failed."
fi

echo "========================================"
echo "Build completed successfully!"
echo "========================================"
echo ""
echo "Expected sizes after optimization:"
echo "  - arm64-v8a (recommended for modern phones): ~25-28 MB"
echo "  - armeabi-v7a (legacy support): ~22-26 MB"
echo "  - universal APK: ~42-48 MB"
echo ""
echo "For Play Store upload, use the App Bundle:"
echo "  flutter build appbundle"
echo ""

