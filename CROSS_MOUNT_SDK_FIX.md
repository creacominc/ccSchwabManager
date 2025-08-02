# Cross-Mount SDK Configuration Fix

## Problem
When switching between laptop and desktop with a cross-mounted workspace, you may encounter the error:
```
"Unable to determine the current SDK. Use the SDK Manager to set the current SDK."
```

This happens because:
1. Different machines may have different Xcode versions and SDK versions
2. The `launch.json` and `build-config.json` files contain hardcoded SDK versions and DerivedData paths
3. These paths and SDK versions may not be available on the other machine

## Solution

### Automated Fix
Run the enhanced `update-launch-config.sh` script:

```bash
./update-launch-config.sh
```

This script will:
1. Detect the current DerivedData path for your project
2. Detect available SDKs on the current machine
3. Update `launch.json` with the correct paths and SDK versions
4. Update `build-config.json` with the correct SDK versions

### Manual Verification
Run the diagnostic script to check your configuration:

```bash
./check-sdk-config.sh
```

This will show:
- Available SDKs on your system
- Current configuration status
- Build test results
- Recommendations for fixes

## What the Scripts Do

### `update-launch-config.sh`
- Finds the current DerivedData path for ccSchwabManager
- Detects available macOS, iOS Simulator, and iOS Device SDKs
- Updates `.vscode/launch.json` with correct paths and SDK versions
- Updates `build-config.json` with correct SDK versions

### `check-sdk-config.sh`
- Verifies Xcode command line tools are installed
- Shows all available SDKs
- Checks for hardcoded paths in configuration files
- Tests if the project builds successfully
- Provides troubleshooting recommendations

## When to Run
Run these scripts when:
1. Switching between machines with different Xcode versions
2. After updating Xcode
3. When you see SDK-related errors
4. When DerivedData paths change

## Troubleshooting

### If you still see SDK errors:
1. Make sure both machines have compatible Xcode versions
2. Check that the required SDKs are available on both machines
3. Run `xcodebuild -showsdks` to see available SDKs
4. Update Xcode if necessary

### If the project doesn't build:
1. Run `./update-launch-config.sh` to update SDK versions
2. Check that all required SDKs are available
3. Try building manually with `xcodebuild` to see specific errors

## Files Modified
- `.vscode/launch.json` - Updated with correct DerivedData paths and SDK versions
- `build-config.json` - Updated with correct SDK versions

## Notes
- The scripts are designed to work with different SDK versions
- They use fallback defaults if SDK detection fails
- The configuration is machine-specific and will be updated when you switch machines
