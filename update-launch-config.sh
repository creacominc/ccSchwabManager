#!/bin/bash

# Find the DerivedData path for ccSchwabManager
DERIVED_DATA_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "*ccSchwabManager*" -type d -maxdepth 1 | head -1)

if [ -z "$DERIVED_DATA_PATH" ]; then
    echo "Could not find DerivedData path for ccSchwabManager"
    exit 1
fi

echo "Found DerivedData path: $DERIVED_DATA_PATH"

# Update the launch.json file with the correct path
sed -i '' "s|/Users/haroldt/Library/Developer/Xcode/DerivedData/ccSchwabManager-elnasotrychggcaqjrytumjlyghe|$DERIVED_DATA_PATH|g" .vscode/launch.json

echo "Updated .vscode/launch.json with correct DerivedData path" 