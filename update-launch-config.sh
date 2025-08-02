#!/bin/bash

# Find the DerivedData path for ccSchwabManager
DERIVED_DATA_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "*ccSchwabManager*" -type d -maxdepth 1 | head -1)

if [ -z "$DERIVED_DATA_PATH" ]; then
    echo "Could not find DerivedData path for ccSchwabManager"
    exit 1
fi

echo "Found DerivedData path: $DERIVED_DATA_PATH"

# Get available SDKs
echo "Detecting available SDKs..."

# Get macOS SDK - look for the line that contains "macOS" and extract the SDK identifier
MACOS_SDK=$(xcodebuild -showsdks | grep "macOS" | grep -v "SDKs:" | head -1 | sed 's/.*-sdk \([^[:space:]]*\).*/\1/')
if [ -z "$MACOS_SDK" ] || [ "$MACOS_SDK" = "macOS" ]; then
    echo "Warning: Could not detect macOS SDK, using default"
    MACOS_SDK="macosx15.5"
else
    echo "Detected macOS SDK: $MACOS_SDK"
fi

# Get iOS Simulator SDK - look for the line that contains "Simulator - iOS" and extract the SDK identifier
IOS_SIM_SDK=$(xcodebuild -showsdks | grep "Simulator - iOS" | head -1 | sed 's/.*-sdk \([^[:space:]]*\).*/\1/')
if [ -z "$IOS_SIM_SDK" ]; then
    echo "Warning: Could not detect iOS Simulator SDK, using default"
    IOS_SIM_SDK="iphonesimulator18.5"
else
    echo "Detected iOS Simulator SDK: $IOS_SIM_SDK"
fi

# Get iOS Device SDK - look for the line that contains "iOS" (not Simulator) and extract the SDK identifier
IOS_DEVICE_SDK=$(xcodebuild -showsdks | grep "iOS" | grep -v "Simulator" | grep -v "SDKs:" | head -1 | sed 's/.*-sdk \([^[:space:]]*\).*/\1/')
if [ -z "$IOS_DEVICE_SDK" ] || [ "$IOS_DEVICE_SDK" = "iOS" ]; then
    echo "Warning: Could not detect iOS Device SDK, using default"
    IOS_DEVICE_SDK="iphoneos18.5"
else
    echo "Detected iOS Device SDK: $IOS_DEVICE_SDK"
fi

# Update the launch.json file with the correct paths and SDKs
echo "Updating .vscode/launch.json..."

# Create a temporary file for the updated launch.json
TEMP_FILE=$(mktemp)

# Read the current launch.json and replace the paths and SDKs
perl -pe "s|/Users/haroldt/Library/Developer/Xcode/DerivedData/ccSchwabManager-[a-zA-Z0-9]*|$DERIVED_DATA_PATH|g; s|-sdk macosx[0-9.]*|-sdk $MACOS_SDK|g; s|-sdk iphonesimulator[0-9.]*|-sdk $IOS_SIM_SDK|g" \
    .vscode/launch.json > "$TEMP_FILE"

# Replace the original file
mv "$TEMP_FILE" .vscode/launch.json

echo "Updated .vscode/launch.json with:"
echo "  - DerivedData path: $DERIVED_DATA_PATH"
echo "  - macOS SDK: $MACOS_SDK"
echo "  - iOS Simulator SDK: $IOS_SIM_SDK"

# Update the build-config.json file with the correct SDKs
echo "Updating build-config.json..."

# Create a temporary file for the updated build-config.json
TEMP_CONFIG_FILE=$(mktemp)

# Read the current build-config.json and replace the SDKs
sed -e "s|\"sdk\": \"macosx[0-9.]*\"|\"sdk\": \"$MACOS_SDK\"|g" \
    -e "s|\"sdk\": \"iphonesimulator[0-9.]*\"|\"sdk\": \"$IOS_SIM_SDK\"|g" \
    -e "s|\"sdk\": \"iphoneos[0-9.]*\"|\"sdk\": \"$IOS_DEVICE_SDK\"|g" \
    build-config.json > "$TEMP_CONFIG_FILE"

# Replace the original file
mv "$TEMP_CONFIG_FILE" build-config.json

echo "Updated build-config.json with:"
echo "  - macOS SDK: $MACOS_SDK"
echo "  - iOS Simulator SDK: $IOS_SIM_SDK"
echo "  - iOS Device SDK: $IOS_DEVICE_SDK"
