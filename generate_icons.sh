#!/bin/bash

# Icon Generator Script for ccSchwabManager
# This script takes a source image and generates all required app icons
# Usage: ./generate_icons.sh <source_image_path>

set -e

# Check if source image is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <source_image_path>"
    echo "Example: $0 ~/Downloads/cornucopia.png"
    exit 1
fi

SOURCE_IMAGE="$1"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: Source image '$SOURCE_IMAGE' not found"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define output directories
APPICON_DIR="$SCRIPT_DIR/ccSchwabManager/Assets.xcassets/AppIcon.appiconset"
VISIONOS_FRONT="$SCRIPT_DIR/ccSchwabManager/Assets.xcassets/AppIcon-visionOS.solidimagestack/Front.solidimagestacklayer"
VISIONOS_MIDDLE="$SCRIPT_DIR/ccSchwabManager/Assets.xcassets/AppIcon-visionOS.solidimagestack/Middle.solidimagestacklayer"
VISIONOS_BACK="$SCRIPT_DIR/ccSchwabManager/Assets.xcassets/AppIcon-visionOS.solidimagestack/Back.solidimagestacklayer"

echo "🎨 Generating app icons from: $SOURCE_IMAGE"
echo ""

# Function to generate an icon at a specific size
generate_icon() {
    local size=$1
    local output_file=$2
    local output_dir=$(dirname "$output_file")
    
    # Create directory if it doesn't exist
    mkdir -p "$output_dir"
    
    echo "  → Generating ${size}x${size} icon: $(basename "$output_file")"
    
    # Use sips to resize the image
    # -z height width: set the image height and width
    # --out: specify output file
    sips -z "$size" "$size" "$SOURCE_IMAGE" --out "$output_file" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "    ✓ Created successfully"
    else
        echo "    ✗ Failed to create"
        return 1
    fi
}

echo "📱 Generating iOS/iPadOS icons..."
generate_icon 1024 "$APPICON_DIR/icon_1024 1.png"  # Tinted
generate_icon 1024 "$APPICON_DIR/icon_1024 2.png"  # Dark
generate_icon 1024 "$APPICON_DIR/icon_1024 3.png"  # Regular
echo ""

echo "💻 Generating macOS icons..."
generate_icon 16 "$APPICON_DIR/icon_16 1.png"
generate_icon 32 "$APPICON_DIR/icon_32.png"
generate_icon 64 "$APPICON_DIR/icon_64.png"
generate_icon 128 "$APPICON_DIR/icon_128.png"
generate_icon 256 "$APPICON_DIR/icon_256.png"
generate_icon 256 "$APPICON_DIR/icon_256 2.png"  # Alternative 256
generate_icon 512 "$APPICON_DIR/icon_512.png"
generate_icon 512 "$APPICON_DIR/icon_512 1.png"  # Alternative 512
generate_icon 1024 "$APPICON_DIR/icon_1024 4.png"  # macOS 1024
echo ""

echo "🥽 Generating visionOS icons..."
# For visionOS, we create three layers (Front, Middle, Back)
# Front layer - full image
generate_icon 1024 "$VISIONOS_FRONT/Front.png"

# Middle layer - slightly blurred/faded version
echo "  → Generating Middle layer (slightly adjusted)"
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$VISIONOS_MIDDLE/Middle.png" > /dev/null 2>&1
# Reduce saturation slightly for middle layer
sips -s saturation 0.8 "$VISIONOS_MIDDLE/Middle.png" > /dev/null 2>&1

# Back layer - more blurred/faded version  
echo "  → Generating Back layer (more adjusted)"
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$VISIONOS_BACK/Back.png" > /dev/null 2>&1
# Reduce saturation more for back layer
sips -s saturation 0.6 "$VISIONOS_BACK/Back.png" > /dev/null 2>&1
echo ""

echo "✅ Icon generation complete!"
echo ""
echo "📋 Summary:"
echo "  • iOS/iPadOS icons: 3 variants at 1024x1024"
echo "  • macOS icons: 9 sizes from 16x16 to 1024x1024"
echo "  • visionOS icons: 3 layers (Front, Middle, Back)"
echo ""
echo "🔄 Next steps:"
echo "  1. Open the project in Xcode"
echo "  2. Clean the build folder (Shift+Cmd+K)"
echo "  3. Build and run to see your new icons"
echo ""

