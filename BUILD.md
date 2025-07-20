# ccSchwabManager Build System

This document describes the build system setup for the ccSchwabManager project, which provides multiple ways to build and test the application without needing to open Xcode.

## Overview

The build system consists of:
- **`build.sh`** - Basic build script with essential commands
- **`build-enhanced.sh`** - Advanced build script with configuration file support
- **`build-config.json`** - Configuration file for build settings
- **`Makefile`** - Simple make commands for common tasks

## Quick Start

### Using Make (Recommended)

```bash
# Build the app
make build

# Run unit tests
make test

# Run UI tests
make ui-test

# Build and run all tests
make all

# Launch the app
make launch

# Clean build artifacts
make clean

# Show build information
make info

# Quick build and launch
make quick
```

### Using Enhanced Build Script

```bash
# Build the app
./build-enhanced.sh build

# Run unit tests
./build-enhanced.sh test

# Run UI tests
./build-enhanced.sh ui-test

# Build and run all tests
./build-enhanced.sh all

# Launch the app
./build-enhanced.sh launch

# Clean build artifacts
./build-enhanced.sh clean

# Show build information
./build-enhanced.sh info
```

### Using Basic Build Script

```bash
# Build the app
./build.sh build

# Run unit tests
./build.sh test

# Run UI tests
./build.sh ui-test

# Build and run all tests
./build.sh all

# Launch the app
./build.sh launch

# Clean build artifacts
./build.sh clean
```

## Configuration

### Build Configuration File (`build-config.json`)

The enhanced build script reads configuration from `build-config.json`:

```json
{
  "project": {
    "name": "ccSchwabManager",
    "scheme": "ccSchwabManager",
    "xcodeproj": "ccSchwabManager.xcodeproj"
  },
  "builds": {
    "debug": {
      "configuration": "Debug",
      "destination": "platform=macOS",
      "build_for_testing": true,
      "enable_testing": true
    },
    "release": {
      "configuration": "Release",
      "destination": "platform=macOS",
      "build_for_testing": false,
      "enable_testing": false
    }
  },
  "tests": {
    "unit_tests": {
      "target": "ccSchwabManagerTests",
      "enabled": true,
      "timeout": 300
    },
    "ui_tests": {
      "target": "ccSchwabManagerUITests",
      "enabled": true,
      "timeout": 600
    }
  },
  "options": {
    "parallel_build": true,
    "show_build_timings": true,
    "enable_code_coverage": false,
    "enable_address_sanitizer": false,
    "enable_thread_sanitizer": false
  }
}
```

### Environment Variables

You can override configuration using environment variables:

```bash
# Build with Release configuration
BUILD_CONFIG=Release make build

# Build for iOS (if supported)
DESTINATION=platform=iOS make build

# Combine multiple options
BUILD_CONFIG=Release DESTINATION=platform=macOS make build
```

## Build Commands

### App Building

```bash
# Basic build
make build

# Release build
make release

# Build with specific configuration
BUILD_CONFIG=Release make build
```

### Testing

```bash
# Run unit tests
make test

# Run UI tests
make ui-test

# Run all tests
make all

# Run tests with code coverage
make test-coverage
```

### App Management

```bash
# Launch the built app
make launch

# Quick build and launch
make quick

# Clean build artifacts
make clean
```

### Information

```bash
# Show build configuration
make info

# Show project status
make status

# Show help
make help
```

## Advanced Usage

### Custom Build Configurations

You can create custom build configurations by modifying `build-config.json`:

```json
{
  "builds": {
    "debug": {
      "configuration": "Debug",
      "destination": "platform=macOS"
    },
    "release": {
      "configuration": "Release", 
      "destination": "platform=macOS"
    },
    "profile": {
      "configuration": "Debug",
      "destination": "platform=macOS"
    }
  }
}
```

### Test Timeouts

Configure test timeouts in `build-config.json`:

```json
{
  "tests": {
    "unit_tests": {
      "timeout": 300
    },
    "ui_tests": {
      "timeout": 600
    }
  }
}
```

### Build Options

Enable/disable build features:

```json
{
  "options": {
    "parallel_build": true,
    "show_build_timings": true,
    "enable_code_coverage": true,
    "enable_address_sanitizer": false
  }
}
```

## Troubleshooting

### Common Issues

1. **Build fails with scheme not found**
   - Ensure the scheme is properly configured in Xcode
   - Check that the scheme name in `build-config.json` matches Xcode

2. **Tests fail to run**
   - The scheme may not be configured for testing
   - Try building test targets individually
   - Check that test targets exist in the project

3. **App not found when launching**
   - Build the app first: `make build`
   - Check that the build completed successfully
   - Verify the app path in the build output

4. **Permission denied errors**
   - Make scripts executable: `chmod +x build*.sh`
   - Check file permissions on the project directory

### Debug Mode

Enable debug output by modifying the build scripts or using verbose xcodebuild:

```bash
# Verbose build output
xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager -verbose build
```

## Integration with CI/CD

The build scripts are designed to work with continuous integration systems:

```yaml
# Example GitHub Actions workflow
name: Build and Test
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build and Test
        run: |
          chmod +x build-enhanced.sh
          ./build-enhanced.sh all
```

## Performance Tips

1. **Use parallel builds**: Enabled by default in the configuration
2. **Clean regularly**: Use `make clean` to remove old build artifacts
3. **Use Release builds**: For production testing, use `make release`
4. **Monitor build times**: Enable build timing summaries in configuration

## File Structure

```
ccSchwabManager/
├── build.sh              # Basic build script
├── build-enhanced.sh     # Enhanced build script
├── build-config.json     # Build configuration
├── Makefile              # Make commands
├── BUILD.md              # This documentation
└── ccSchwabManager.xcodeproj/
    └── project.pbxproj   # Xcode project file
```

## Support

For issues with the build system:

1. Check the troubleshooting section above
2. Verify your Xcode installation and command line tools
3. Ensure all required files are present and executable
4. Check the build configuration matches your project setup 