# Build Configuration Update Summary

## Overview
Updated the build configuration to support the latest macOS and iOS versions, ensuring builds target the same location that Xcode uses.

## Changes Made

### 1. Updated Deployment Targets
- **macOS**: Updated from 15.2 to 15.5
- **iOS**: Already at 18.5 (latest)

### 2. Updated Build Configuration (`build-config.json`)
- Added SDK specifications for all build targets
- Added comprehensive build configurations for:
  - macOS Debug/Release
  - iOS Simulator Debug/Release  
  - iOS Device Debug/Release
- Updated iOS simulator destination to use iPhone 16 Pro (available device)

### 3. Enhanced Build Script (`build-enhanced.sh`)
- Added SDK support with `-sdk` parameter
- Added platform-specific build functions
- Updated JSON parsing to handle nested keys properly
- Added comprehensive platform support:
  - `macos` / `macos-release`
  - `ios-simulator` / `ios-simulator-release`
  - `ios-device` / `ios-device-release`

### 4. Updated VS Code Configuration
- **Launch Configuration** (`.vscode/launch.json`):
  - Added separate configurations for macOS and iOS
  - Updated to use latest SDKs
  - Added platform-specific build tasks
- **Tasks Configuration** (`.vscode/tasks.json`):
  - Added platform-specific build tasks
  - Updated to use enhanced build script

### 5. Updated Xcode Project
- Updated `MACOSX_DEPLOYMENT_TARGET` from 15.2 to 15.5
- iOS deployment target already at 18.5

## Build Commands

### Available Build Commands
```bash
# macOS builds
./build-enhanced.sh build macos              # Debug
./build-enhanced.sh build macos-release      # Release

# iOS Simulator builds  
./build-enhanced.sh build ios-simulator      # Debug
./build-enhanced.sh build ios-simulator-release  # Release

# iOS Device builds
./build-enhanced.sh build ios-device         # Debug
./build-enhanced.sh build ios-device-release # Release

# Other commands
./build-enhanced.sh info                     # Show configuration
./build-enhanced.sh clean                    # Clean build artifacts
./build-enhanced.sh test                     # Run unit tests
./build-enhanced.sh ui-test                 # Run UI tests
```

### VS Code Integration
- Use the Debug/Run configurations in VS Code
- Build tasks available in Command Palette
- Platform-specific launch configurations

## SDK Versions Used
- **macOS**: `macosx15.5`
- **iOS Simulator**: `iphonesimulator18.5`
- **iOS Device**: `iphoneos18.5`

## Build Locations
Builds now target the same location that Xcode uses:
- **macOS**: `~/Library/Developer/Xcode/DerivedData/[Project]/Build/Products/Debug/ccSchwabManager.app`
- **iOS Simulator**: `~/Library/Developer/Xcode/DerivedData/[Project]/Build/Products/Debug-iphonesimulator/ccSchwabManager.app`

## Verification
Both macOS and iOS builds have been tested and confirmed working with the latest SDKs and deployment targets. 