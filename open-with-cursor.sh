#!/bin/bash

# Open the project with Cursor using the workspace file
echo "Opening ccSchwabManager project with Cursor..."
echo "Make sure to close any existing Cursor windows first."

# Check if workspace file exists
if [ -f "ccSchwabManager.code-workspace" ]; then
    echo "Opening with workspace file..."
    code ccSchwabManager.code-workspace
else
    echo "Workspace file not found, opening with regular folder..."
    code .
fi

echo ""
echo "If the Run and Debug panel still doesn't show the configurations:"
echo "1. Press Cmd+Shift+P to open command palette"
echo "2. Type 'Developer: Reload Window' and press Enter"
echo "3. Or try 'File: Open Folder' and select this directory again"
echo ""
echo "The debug configurations should appear in the Run and Debug panel (Cmd+Shift+D)" 