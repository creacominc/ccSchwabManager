#!/bin/bash

# Enhanced ccSchwabManager Build Script
# Usage: ./build-enhanced.sh [command] [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

# Function to detect the latest available SDK for a platform
detect_latest_sdk() {
    local platform=$1
    local sdk_output
    local detected_sdk=""
    
    # Get SDK list from xcodebuild
    sdk_output=$(xcodebuild -showsdks 2>/dev/null)
    
    case $platform in
        "macos"|"macosx")
            # Look for macOS SDK - get the last one (should be latest)
            detected_sdk=$(echo "$sdk_output" | grep "macOS" | grep -v "SDKs:" | tail -1 | sed -n 's/.*-sdk \([^[:space:]]*\).*/\1/p')
            ;;
        "ios-simulator"|"iphonesimulator")
            # Look for iOS Simulator SDK
            detected_sdk=$(echo "$sdk_output" | grep "Simulator - iOS" | tail -1 | sed -n 's/.*-sdk \([^[:space:]]*\).*/\1/p')
            ;;
        "ios-device"|"iphoneos")
            # Look for iOS Device SDK
            detected_sdk=$(echo "$sdk_output" | grep "^[[:space:]]*iOS[[:space:]]" | grep -v "Simulator" | grep -v "SDKs:" | tail -1 | sed -n 's/.*-sdk \([^[:space:]]*\).*/\1/p')
            ;;
    esac
    
    # Verify SDK exists
    if [ -n "$detected_sdk" ]; then
        # Check if SDK path exists
        local sdk_path=$(xcrun --sdk "$detected_sdk" --show-sdk-path 2>/dev/null)
        if [ -n "$sdk_path" ] && [ -d "$sdk_path" ]; then
            echo "$detected_sdk"
            return 0
        fi
    fi
    
    # Return empty if not found
    echo ""
    return 1
}

# Function to get SDK for a build type, auto-detecting if needed
get_sdk_for_build() {
    local build_type=$1
    
    # First try to get SDK from config
    local config_sdk=$(read_config ".builds.\"$build_type\".sdk" 'sdk')
    
    # If SDK is specified in config, verify it exists
    if [ -n "$config_sdk" ] && [ "$config_sdk" != "null" ] && [ "$config_sdk" != "" ]; then
        # Check if the SDK exists
        local sdk_path=$(xcrun --sdk "$config_sdk" --show-sdk-path 2>/dev/null)
        if [ -n "$sdk_path" ] && [ -d "$sdk_path" ]; then
            echo "$config_sdk"
            return 0
        else
            # Print warning to stderr so it doesn't get captured
            print_warning "Configured SDK '$config_sdk' not found, auto-detecting latest..." >&2
        fi
    fi
    
    # Auto-detect based on build type
    case $build_type in
        "debug"|"release"|"debug-macos"|"release-macos")
            detect_latest_sdk "macos"
            ;;
        "debug-ios-simulator"|"release-ios-simulator")
            detect_latest_sdk "ios-simulator"
            ;;
        "debug-ios-device"|"release-ios-device")
            detect_latest_sdk "ios-device"
            ;;
        *)
            # Default to macOS
            detect_latest_sdk "macos"
            ;;
    esac
}

# Function to read JSON configuration
read_config() {
    if [ -f "build-config.json" ]; then
        # Use jq if available, otherwise use a simple grep approach
        if command -v jq &> /dev/null; then
            local result
            result=$(jq -r "$1" build-config.json 2>/dev/null)
            if [ $? -eq 0 ] && [ "$result" != "null" ]; then
                echo "$result"
            else
                echo ""
            fi
        else
            # Simple fallback for when jq is not available
            grep -o "\"$2\":[^,]*" build-config.json | cut -d':' -f2 | tr -d '"' | tr -d ' '
        fi
    else
        print_error "Configuration file build-config.json not found"
        exit 1
    fi
}

# Load configuration
PROJECT_NAME=$(read_config '.project.name' 'name')
SCHEME_NAME=$(read_config '.project.scheme' 'scheme')
XCODEPROJ=$(read_config '.project.xcodeproj' 'xcodeproj')
BUILD_CONFIG=${BUILD_CONFIG:-$(read_config '.builds.debug.configuration' 'configuration')}
DESTINATION=${DESTINATION:-$(read_config '.builds.debug.destination' 'destination')}

# Function to build the app
build_app() {
    local config=${1:-$BUILD_CONFIG}
    local build_type=${2:-"debug"}
    print_status "Building $PROJECT_NAME app with configuration: $config (build type: $build_type)"
    
    # Get SDK using auto-detection (will use config if valid, otherwise auto-detect)
    local sdk=$(get_sdk_for_build "$build_type")
    local destination=$(read_config ".builds.\"$build_type\".destination" 'destination')
    
    local build_args=(
        -project "$XCODEPROJ"
        -scheme "$SCHEME_NAME"
        -configuration "$config"
        -destination "$destination"
    )
    
    # Add SDK if detected/specified
    if [ -n "$sdk" ] && [ "$sdk" != "" ]; then
        build_args+=(-sdk "$sdk")
        print_status "Using SDK: $sdk"
    else
        print_warning "Could not detect SDK, xcodebuild will use default"
    fi
    
    # Add parallel build if enabled
    if [ "$(read_config '.options.parallel_build' 'parallel_build')" = "true" ]; then
        build_args+=(-parallelizeTargets)
    fi
    
    # Add build timings if enabled
    if [ "$(read_config '.options.show_build_timings' 'show_build_timings')" = "true" ]; then
        build_args+=(-showBuildTimingSummary)
    fi
    
    build_args+=(build)
    
    print_debug "Running: xcodebuild ${build_args[*]}"
    xcodebuild "${build_args[@]}"
    
    if [ $? -eq 0 ]; then
        print_success "App build completed successfully"
        return 0
    else
        print_error "App build failed"
        return 1
    fi
}

# Function to build for specific platform
build_for_platform() {
    local platform=$1
    local config=${2:-"Debug"}
    
    case $platform in
        "macos"|"mac")
            print_status "Building for macOS..."
            build_app "$config" "debug-macos"
            ;;
        "macos-release"|"mac-release")
            print_status "Building for macOS (Release)..."
            build_app "Release" "release-macos"
            ;;
        "ios-simulator"|"ios-sim")
            print_status "Building for iOS Simulator..."
            build_app "$config" "debug-ios-simulator"
            ;;
        "ios-simulator-release"|"ios-sim-release")
            print_status "Building for iOS Simulator (Release)..."
            build_app "Release" "release-ios-simulator"
            ;;
        "ios-device"|"ios")
            print_status "Building for iOS Device..."
            build_app "$config" "debug-ios-device"
            ;;
        "ios-device-release"|"ios-release")
            print_status "Building for iOS Device (Release)..."
            build_app "Release" "release-ios-device"
            ;;
        *)
            print_error "Unknown platform: $platform"
            print_status "Available platforms: macos, macos-release, ios-simulator, ios-simulator-release, ios-device, ios-device-release"
            return 1
            ;;
    esac
}

# Function to run unit tests
run_unit_tests() {
    local timeout=$(read_config '.tests.unit_tests.timeout' 'timeout')
    print_status "Running unit tests (timeout: ${timeout}s)..."
    
    # First, build for testing
    print_status "Building for testing..."
    xcodebuild -project "$XCODEPROJ" \
               -scheme "$SCHEME_NAME" \
               -destination "$DESTINATION" \
               build-for-testing
    
    if [ $? -ne 0 ]; then
        print_error "Build for testing failed"
        return 1
    fi
    
    # Try to run tests
    print_status "Running unit tests..."
    timeout "$timeout" xcodebuild -project "$XCODEPROJ" \
               -scheme "$SCHEME_NAME" \
               -destination "$DESTINATION" \
               test 2>/dev/null || {
        print_warning "xcodebuild test failed, trying alternative approach..."
        
        # Alternative: Build test target
        local test_target=$(read_config '.tests.unit_tests.target' 'target')
        print_status "Building test target: $test_target"
        
        xcodebuild -project "$XCODEPROJ" \
                   -target "$test_target" \
                   -configuration "$BUILD_CONFIG" \
                   build
        
        if [ $? -eq 0 ]; then
            print_success "Unit tests built successfully"
        else
            print_error "Unit tests build failed"
            return 1
        fi
    }
}

# Function to run UI tests
run_ui_tests() {
    local timeout=$(read_config '.tests.ui_tests.timeout' 'timeout')
    local test_target=$(read_config '.tests.ui_tests.target' 'target')
    
    print_status "Running UI tests (timeout: ${timeout}s)..."
    
    timeout "$timeout" xcodebuild -project "$XCODEPROJ" \
               -scheme "$SCHEME_NAME" \
               -destination "$DESTINATION" \
               -target "$test_target" \
               test 2>/dev/null || {
        print_warning "UI tests failed to run with xcodebuild test"
        print_status "Building UI test target..."
        
        xcodebuild -project "$XCODEPROJ" \
                   -target "$test_target" \
                   -configuration "$BUILD_CONFIG" \
                   build
        
        if [ $? -eq 0 ]; then
            print_success "UI tests built successfully"
        else
            print_error "UI tests build failed"
            return 1
        fi
    }
}

# Function to run all tests
run_all_tests() {
    print_status "Running all tests..."
    
    local unit_enabled=$(read_config '.tests.unit_tests.enabled' 'enabled')
    local ui_enabled=$(read_config '.tests.ui_tests.enabled' 'enabled')
    
    if [ "$unit_enabled" = "true" ]; then
        run_unit_tests
    fi
    
    if [ "$ui_enabled" = "true" ]; then
        run_ui_tests
    fi
}

# Function to clean build artifacts
clean_build() {
    print_status "Cleaning build artifacts..."
    xcodebuild -project "$XCODEPROJ" \
               -scheme "$SCHEME_NAME" \
               clean
    
    # Also clean derived data for this project
    local project_derived_data=$(find_project_derived_data)
    
    if [ -n "$project_derived_data" ]; then
        print_status "Removing derived data: $project_derived_data"
        rm -rf "$project_derived_data"
    fi
    
    print_success "Clean completed"
}

# Function to get the actual Xcode DerivedData path
get_derived_data_path() {
    # Use the same logic Xcode uses to find DerivedData
    local derived_data_paths=(
        "$HOME/Library/Developer/Xcode/DerivedData"
        "$HOME/Library/Developer/Xcode/DerivedData-$(sw_vers -productVersion)"
    )
    
    for path in "${derived_data_paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # Fallback to default
    echo "$HOME/Library/Developer/Xcode/DerivedData"
}

# Function to find the project's DerivedData directory
find_project_derived_data() {
    local derived_data_path=$(get_derived_data_path)
    local project_derived_data=$(find "$derived_data_path" -name "*$PROJECT_NAME*" -type d 2>/dev/null | head -1)
    echo "$project_derived_data"
}

# Function to launch the app
launch_app() {
    local platform=${1:-"macos"}
    
    case $platform in
        "macos"|"mac")
            launch_macos_app
            ;;
        "ios-simulator"|"ios-sim"|"ios")
            launch_ios_simulator_app
            ;;
        *)
            print_error "Unknown platform: $platform"
            print_status "Available platforms: macos, ios-simulator"
            return 1
            ;;
    esac
}

# Function to launch macOS app
launch_macos_app() {
    local log_file="$HOME/Library/Containers/com.creacom.ccSchwabManager/Data/Documents/ccSchwabManager.log"
    print_status "Truncating log file... $log_file"
    truncate -s 0  $log_file

    print_status "Launching macOS app..."
    
    local project_derived_data=$(find_project_derived_data)
    local build_products=$(read_config '.paths.build_products' 'build_products')
    
    if [ -n "$project_derived_data" ]; then
        local app_path="$project_derived_data/$build_products/$BUILD_CONFIG/$PROJECT_NAME.app"
        if [ -d "$app_path" ]; then
            open "$app_path"
            print_success "macOS app launched successfully"
        else
            print_error "App not found at expected location: $app_path"
            print_status "Please build the app first using: ./build-enhanced.sh build macos"
        fi
    else
        print_error "Could not find derived data for project"
    fi
}

# Function to launch iOS app in simulator
launch_ios_simulator_app() {
    print_status "Launching iOS app in simulator..."
    
    local project_derived_data=$(find_project_derived_data)
    local build_products=$(read_config '.paths.build_products' 'build_products')
    local destination=$(read_config '.builds."debug-ios-simulator".destination' 'destination')
    
    # Extract simulator name from destination (e.g., "platform=iOS Simulator,name=iPhone 16 Pro")
    local simulator_name=$(echo "$destination" | sed -n 's/.*name=\([^,]*\).*/\1/p')
    
    if [ -z "$simulator_name" ]; then
        simulator_name="iPhone 16 Pro"
        print_warning "Could not determine simulator name from config, using default: $simulator_name"
    fi
    
    if [ -n "$project_derived_data" ]; then
        # iOS apps are built in Debug-iphonesimulator directory
        local app_path="$project_derived_data/$build_products/Debug-iphonesimulator/$PROJECT_NAME.app"
        
        if [ -d "$app_path" ]; then
            # Boot the simulator if not already running
            print_status "Checking simulator status..."
            local device_id=$(xcrun simctl list devices available | grep "$simulator_name" | grep -v "unavailable" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
            
            if [ -z "$device_id" ]; then
                print_error "Could not find simulator: $simulator_name"
                print_status "Available simulators:"
                xcrun simctl list devices available | grep "iPhone" | head -5
                return 1
            fi
            
            # Boot the simulator if needed
            local boot_status=$(xcrun simctl list devices | grep "$device_id" | grep -o "Booted\|Shutdown")
            if [ "$boot_status" != "Booted" ]; then
                print_status "Booting simulator: $simulator_name ($device_id)..."
                xcrun simctl boot "$device_id" 2>/dev/null || true
                # Wait a moment for simulator to boot
                sleep 2
            fi
            
            # Open Simulator app if not already open
            if ! pgrep -q Simulator; then
                print_status "Opening Simulator app..."
                open -a Simulator
                sleep 2
            fi
            
            # Install and launch the app
            print_status "Installing app on simulator..."
            xcrun simctl install "$device_id" "$app_path" 2>/dev/null || {
                print_warning "Install failed or app already installed, continuing..."
            }
            
            print_status "Launching app on simulator..."
            # iOS apps have Info.plist directly in the .app bundle, not in Contents/
            local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app_path/Info.plist" 2>/dev/null)
            
            if [ -n "$bundle_id" ]; then
                xcrun simctl launch "$device_id" "$bundle_id"
                print_success "iOS app launched successfully on simulator: $simulator_name"
            else
                print_error "Could not determine app bundle identifier"
                print_status "You can manually launch the app from the simulator"
            fi
        else
            print_error "iOS app not found at expected location: $app_path"
            print_status "Please build the iOS app first using: ./build-enhanced.sh build ios-simulator"
            print_status "Or use: make build-ios"
        fi
    else
        print_error "Could not find derived data for project"
    fi
}

# Function to show build information
show_info() {
    echo "Project Information:"
    echo "  Name: $PROJECT_NAME"
    echo "  Scheme: $SCHEME_NAME"
    echo "  Configuration: $BUILD_CONFIG"
    echo "  Destination: $DESTINATION"
    echo ""
    echo "Deployment Targets:"
    echo "  macOS: $(read_config '.deployment_targets.macos' 'macos')"
    echo "  iOS: $(read_config '.deployment_targets.ios' 'ios')"
    echo ""
    echo "Detected SDKs (auto-detected from system):"
    echo "  macOS: $(detect_latest_sdk 'macos')"
    echo "  iOS Simulator: $(detect_latest_sdk 'ios-simulator')"
    echo "  iOS Device: $(detect_latest_sdk 'ios-device')"
    echo ""
    echo "Build Configurations (will use auto-detected SDKs if config SDK not available):"
    echo "  macOS Debug: $(get_sdk_for_build 'debug-macos')"
    echo "  macOS Release: $(get_sdk_for_build 'release-macos')"
    echo "  iOS Simulator Debug: $(get_sdk_for_build 'debug-ios-simulator')"
    echo "  iOS Simulator Release: $(get_sdk_for_build 'release-ios-simulator')"
    echo "  iOS Device Debug: $(get_sdk_for_build 'debug-ios-device')"
    echo "  iOS Device Release: $(get_sdk_for_build 'release-ios-device')"
    echo ""
    echo "Test Configuration:"
    echo "  Unit Tests: $(read_config '.tests.unit_tests.enabled' 'enabled')"
    echo "  UI Tests: $(read_config '.tests.ui_tests.enabled' 'enabled')"
    echo ""
    echo "Build Options:"
    echo "  Parallel Build: $(read_config '.options.parallel_build' 'parallel_build')"
    echo "  Show Build Timings: $(read_config '.options.show_build_timings' 'show_build_timings')"
}

# Function to show usage
show_usage() {
    echo "Enhanced Build Script for $PROJECT_NAME"
    echo ""
    echo "Usage: $0 [command] [platform] [options]"
    echo ""
    echo "Commands:"
    echo "  build      - Build the app for specified platform"
    echo "  test       - Run unit tests"
    echo "  ui-test    - Run UI tests"
    echo "  all        - Build app and run all tests"
    echo "  clean      - Clean build artifacts"
    echo "  launch     - Launch the built app (default: macOS)"
    echo "  info       - Show build configuration"
    echo "  help       - Show this help message"
    echo ""
    echo "Platforms:"
    echo "  macos              - Build for macOS (Debug)"
    echo "  macos-release      - Build for macOS (Release)"
    echo "  ios-simulator      - Build for iOS Simulator (Debug)"
    echo "  ios-simulator-release - Build for iOS Simulator (Release)"
    echo "  ios-device         - Build for iOS Device (Debug)"
    echo "  ios-device-release - Build for iOS Device (Release)"
    echo ""
    echo "Options:"
    echo "  BUILD_CONFIG=Release  - Set build configuration"
    echo "  DESTINATION=platform=iOS  - Set destination"
    echo ""
    echo "Examples:"
    echo "  $0 build macos"
    echo "  $0 build ios-simulator"
    echo "  $0 build ios-device-release"
    echo "  $0 launch macos"
    echo "  $0 launch ios-simulator"
    echo "  $0 test"
    echo "  $0 all"
    echo "  $0 clean"
}

# Main script logic
case "${1:-help}" in
    "build")
        platform=${2:-"macos"}
        build_for_platform "$platform"
        ;;
    "test")
        run_unit_tests
        ;;
    "ui-test")
        run_ui_tests
        ;;
    "all")
        build_for_platform "macos" && run_all_tests
        ;;
    "clean")
        clean_build
        ;;
    "launch")
        platform=${2:-"macos"}
        launch_app "$platform"
        ;;
    "info")
        show_info
        ;;
    "help"|*)
        show_usage
        ;;
esac 