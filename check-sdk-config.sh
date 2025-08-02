#!/bin/bash

echo "=== SDK Configuration Check ==="
echo

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ ERROR: Xcode command line tools not found"
    echo "   Please install Xcode command line tools:"
    echo "   xcode-select --install"
    exit 1
fi

echo "✅ Xcode command line tools found"

# Show available SDKs
echo
echo "=== Available SDKs ==="
xcodebuild -showsdks

echo
echo "=== Current Configuration ==="

# Check launch.json
if [ -f ".vscode/launch.json" ]; then
    echo "✅ .vscode/launch.json exists"
    
    # Get current DerivedData path
    CURRENT_DERIVED_DATA_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "*ccSchwabManager*" -type d -maxdepth 1 | head -1)
    
    # Check for hardcoded paths that don't match current path
    HARDCODED_PATHS=$(grep -c "/Users/haroldt/Library/Developer/Xcode/DerivedData" .vscode/launch.json || echo "0")
    if [ "$HARDCODED_PATHS" -gt 0 ]; then
        # Check if the paths in launch.json match the current DerivedData path
        MISMATCHED_PATHS=$(grep -v "$CURRENT_DERIVED_DATA_PATH" .vscode/launch.json | grep -c "/Users/haroldt/Library/Developer/Xcode/DerivedData" || echo "0")
        if [ "$MISMATCHED_PATHS" -gt 0 ]; then
            echo "⚠️  Found $MISMATCHED_PATHS outdated DerivedData paths in launch.json"
            echo "   Run ./update-launch-config.sh to fix"
        else
            echo "✅ launch.json paths are properly configured"
        fi
    else
        echo "✅ launch.json paths are properly configured"
    fi
else
    echo "❌ .vscode/launch.json not found"
fi

# Check build-config.json
if [ -f "build-config.json" ]; then
    echo "✅ build-config.json exists"
    
    # Check SDK versions
    MACOS_SDK_CONFIG=$(grep -o '"sdk": "macosx[^"]*"' build-config.json | head -1)
    IOS_SIM_SDK_CONFIG=$(grep -o '"sdk": "iphonesimulator[^"]*"' build-config.json | head -1)
    IOS_DEVICE_SDK_CONFIG=$(grep -o '"sdk": "iphoneos[^"]*"' build-config.json | head -1)
    
    echo "   macOS SDK: $MACOS_SDK_CONFIG"
    echo "   iOS Simulator SDK: $IOS_SIM_SDK_CONFIG"
    echo "   iOS Device SDK: $IOS_DEVICE_SDK_CONFIG"
else
    echo "❌ build-config.json not found"
fi

echo
echo "=== Troubleshooting ==="

# Check if DerivedData path exists
DERIVED_DATA_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "*ccSchwabManager*" -type d -maxdepth 1 | head -1)
if [ -z "$DERIVED_DATA_PATH" ]; then
    echo "⚠️  No DerivedData path found for ccSchwabManager"
    echo "   This is normal if you haven't built the project yet"
else
    echo "✅ Found DerivedData path: $DERIVED_DATA_PATH"
fi

# Check if the project builds
echo
echo "=== Build Test ==="
echo "Testing if project can be built..."

# Try a simple build test
if xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager -destination "platform=macOS" -sdk macosx15.5 build -quiet 2>/dev/null; then
    echo "✅ Project builds successfully"
else
    echo "❌ Project build failed"
    echo "   This might be due to SDK version mismatch"
    echo "   Run ./update-launch-config.sh to fix SDK versions"
fi

echo
echo "=== Recommendations ==="
echo "1. Run './update-launch-config.sh' to update SDK versions and paths"
echo "2. If you still see SDK errors, check that Xcode is up to date"
echo "3. Make sure both machines have compatible Xcode versions" 