#!/bin/bash

# Find the DerivedData path for ccSchwabManager
DERIVED_DATA_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "*ccSchwabManager*" -type d -maxdepth 1 | head -1)

if [ -n "$DERIVED_DATA_PATH" ]; then
    echo "$DERIVED_DATA_PATH"
else
    echo "Could not find DerivedData path for ccSchwabManager"
    exit 1
fi 