#!/bin/bash

echo "=== Build Path Checker ==="
echo

echo "1. Xcode DerivedData build path:"
XCODE_PATH="/Users/haroldt/Library/Developer/Xcode/DerivedData/ccSchwabManager-elnasotrychggcaqjrytumjlyghe/Build/Products/Debug/ccSchwabManager.app"
if [ -d "$XCODE_PATH" ]; then
    echo "✅ Found: $XCODE_PATH"
    echo "   Last modified: $(stat -f "%Sm" "$XCODE_PATH")"
    echo "   Executable: $XCODE_PATH/Contents/MacOS/ccSchwabManager"
else
    echo "❌ Not found: $XCODE_PATH"
fi

echo
echo "2. Local build path:"
LOCAL_PATH="./build/Debug/ccSchwabManager.app"
if [ -d "$LOCAL_PATH" ]; then
    echo "✅ Found: $LOCAL_PATH"
    echo "   Last modified: $(stat -f "%Sm" "$LOCAL_PATH")"
    echo "   Executable: $LOCAL_PATH/Contents/MacOS/ccSchwabManager"
else
    echo "❌ Not found: $LOCAL_PATH"
fi

echo
echo "3. Current VS Code launch.json configuration:"
echo "   Using: $XCODE_PATH/Contents/MacOS/ccSchwabManager"

echo
echo "4. To test your logging changes:"
echo "   Run: $XCODE_PATH/Contents/MacOS/ccSchwabManager"
echo "   Or use VS Code/Cursor launch configuration" 