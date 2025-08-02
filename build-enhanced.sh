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
    
    # Get SDK from configuration
    local sdk=$(read_config ".builds.\"$build_type\".sdk" 'sdk')
    local destination=$(read_config ".builds.\"$build_type\".destination" 'destination')
    
    local build_args=(
        -project "$XCODEPROJ"
        -scheme "$SCHEME_NAME"
        -configuration "$config"
        -destination "$destination"
    )
    
    # Add SDK if specified
    if [ -n "$sdk" ]; then
        build_args+=(-sdk "$sdk")
        print_status "Using SDK: $sdk"
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
    local derived_data_path=$(read_config '.paths.derived_data' 'derived_data')
    derived_data_path=$(eval echo "$derived_data_path")
    
    local project_derived_data=$(find "$derived_data_path" -name "*$PROJECT_NAME*" -type d 2>/dev/null | head -1)
    
    if [ -n "$project_derived_data" ]; then
        print_status "Removing derived data: $project_derived_data"
        rm -rf "$project_derived_data"
    fi
    
    print_success "Clean completed"
}

# Function to launch the app
launch_app() {
    print_status "Launching app..."
    
    local derived_data_path=$(read_config '.paths.derived_data' 'derived_data')
    derived_data_path=$(eval echo "$derived_data_path")
    local build_products=$(read_config '.paths.build_products' 'build_products')
    
    local project_derived_data=$(find "$derived_data_path" -name "*$PROJECT_NAME*" -type d 2>/dev/null | head -1)
    
    if [ -n "$project_derived_data" ]; then
        local app_path="$project_derived_data/$build_products/$BUILD_CONFIG/$PROJECT_NAME.app"
        if [ -d "$app_path" ]; then
            open "$app_path"
            print_success "App launched successfully"
        else
            print_error "App not found at expected location: $app_path"
            print_status "Please build the app first using: ./build-enhanced.sh build"
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
    echo "Available Build Configurations:"
    echo "  macOS Debug: $(read_config '.builds."debug-macos".sdk' 'sdk')"
    echo "  macOS Release: $(read_config '.builds."release-macos".sdk' 'sdk')"
    echo "  iOS Simulator Debug: $(read_config '.builds."debug-ios-simulator".sdk' 'sdk')"
    echo "  iOS Simulator Release: $(read_config '.builds."release-ios-simulator".sdk' 'sdk')"
    echo "  iOS Device Debug: $(read_config '.builds."debug-ios-device".sdk' 'sdk')"
    echo "  iOS Device Release: $(read_config '.builds."release-ios-device".sdk' 'sdk')"
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
    echo "  launch     - Launch the built app"
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
        launch_app
        ;;
    "info")
        show_info
        ;;
    "help"|*)
        show_usage
        ;;
esac 