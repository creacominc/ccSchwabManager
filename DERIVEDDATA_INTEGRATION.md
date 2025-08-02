# DerivedData Integration

## Overview
The build system has been updated to use the same DerivedData location as Xcode, ensuring consistency across machines without requiring symlinks.

## How It Works

### 1. Automatic DerivedData Path Detection
The build script now automatically detects the correct DerivedData path using the same logic Xcode uses:

```bash
# Primary path (most common)
~/Library/Developer/Xcode/DerivedData

# Version-specific path (for newer Xcode versions)
~/Library/Developer/Xcode/DerivedData-{macOS_version}
```

### 2. Project-Specific Directory Discovery
The script finds the project's specific DerivedData directory by searching for the project name:

```bash
# Example: ccSchwabManager-elnasotrychggcaqjrytumjlyghe
find ~/Library/Developer/Xcode/DerivedData -name "*ccSchwabManager*"
```

### 3. Build Product Locations
Builds are now placed in the same location Xcode uses:

**macOS:**
```
~/Library/Developer/Xcode/DerivedData/ccSchwabManager-*/Build/Products/Debug/ccSchwabManager.app
```

**iOS Simulator:**
```
~/Library/Developer/Xcode/DerivedData/ccSchwabManager-*/Build/Products/Debug-iphonesimulator/ccSchwabManager.app
```

## Updated Components

### 1. Build Script (`build-enhanced.sh`)
- Added `get_derived_data_path()` function to detect the correct path
- Added `find_project_derived_data()` function to locate project directory
- Updated `launch_app()` and `clean_build()` to use actual DerivedData path

### 2. VS Code Launch Configuration (`.vscode/launch.json`)
- Updated program paths to use `${env:HOME}/Library/Developer/Xcode/DerivedData/ccSchwabManager-*/`
- Uses wildcard pattern to match the unique project directory name

### 3. Build Configuration (`build-config.json`)
- Maintains the DerivedData path configuration for reference
- Build script uses actual path detection instead of relying on configuration

## Benefits

### ✅ **Cross-Machine Compatibility**
- Works on any macOS machine without symlinks
- Automatically adapts to different Xcode versions
- Uses the same paths Xcode uses

### ✅ **No Project Pollution**
- No symlinks or build artifacts in the project directory
- Clean project structure maintained
- DerivedData is properly ignored in `.gitignore`

### ✅ **Consistent Behavior**
- Build script and VS Code use the same locations
- Xcode and command-line builds share the same output
- No conflicts between different build methods

## Usage

### Command Line
```bash
# Build for macOS (uses Xcode's DerivedData)
./build-enhanced.sh build macos

# Build for iOS Simulator (uses Xcode's DerivedData)
./build-enhanced.sh build ios-simulator

# Clean build artifacts (removes from DerivedData)
./build-enhanced.sh clean
```

### VS Code
- Debug configurations automatically find the correct app location
- No need to update paths when switching machines
- Works with any Xcode version

## Machine Independence

The system works across different machines because:

1. **Standard Paths**: Uses the standard `~/Library/Developer/Xcode/DerivedData` path
2. **Dynamic Detection**: Automatically finds the correct path for the current Xcode version
3. **Project Discovery**: Finds the project-specific directory by name pattern
4. **No Hardcoded Paths**: All paths are resolved dynamically

This ensures that the build system works consistently across different development environments without requiring manual configuration or symlinks. 