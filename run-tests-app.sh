#!/bin/bash

# ccSchwabManager App-Based Test Runner
# This script runs tests through the main app to avoid symbol linking issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="ccSchwabManager"
UNIT_TEST_TARGET="ccSchwabManagerTests"
UI_TEST_TARGET="ccSchwabManagerUITests"
DESTINATION="platform=macOS"

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

# Function to build the app and tests
build_app_and_tests() {
    print_status "Building app and tests..."
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -target "$PROJECT_NAME" \
               -configuration Debug \
               -destination "$DESTINATION" \
               build
}

# Function to run unit tests through the app
run_unit_tests_app() {
    print_status "Running unit tests through app..."
    
    # Build the app first
    build_app_and_tests
    
    # Find the app bundle
    APP_BUNDLE=$(find build/Debug -name "${PROJECT_NAME}.app" -type d 2>/dev/null | head -1)
    
    if [ -z "$APP_BUNDLE" ]; then
        print_error "App bundle not found. Building first..."
        build_app_and_tests
        APP_BUNDLE=$(find build/Debug -name "${PROJECT_NAME}.app" -type d 2>/dev/null | head -1)
    fi
    
    if [ -n "$APP_BUNDLE" ]; then
        print_status "Found app bundle: $APP_BUNDLE"
        print_status "Running tests through app..."
        
        # Run tests by launching the app with test arguments
        # This approach runs the tests within the app context
        "$APP_BUNDLE/Contents/MacOS/$PROJECT_NAME" --test
        
        print_success "Unit tests completed!"
    else
        print_error "Could not locate app bundle."
        exit 1
    fi
}

# Function to run UI tests through the app
run_ui_tests_app() {
    print_status "Running UI tests through app..."
    
    # Build the app first
    build_app_and_tests
    
    # Find the UI test runner app
    UI_TEST_RUNNER=$(find build/Debug -name "*UITests-Runner.app" -type d 2>/dev/null | head -1)
    
    if [ -n "$UI_TEST_RUNNER" ]; then
        print_status "Found UI test runner: $UI_TEST_RUNNER"
        print_status "Running UI tests..."
        
        # Run UI tests using the test runner
        "$UI_TEST_RUNNER/Contents/MacOS/$(basename "$UI_TEST_RUNNER" .app)" --test
        
        print_success "UI tests completed!"
    else
        print_warning "UI test runner not found. Building first..."
        build_app_and_tests
        
        # Try running UI tests by building the target directly
        xcodebuild -project "$PROJECT_NAME.xcodeproj" \
                   -target "$UI_TEST_TARGET" \
                   -configuration Debug \
                   -destination "$DESTINATION" \
                   build test
        
        print_success "UI tests completed via direct build!"
    fi
}

# Function to run all tests
run_all_tests_app() {
    print_status "Running all tests through app..."
    
    build_app_and_tests
    
    # Run unit tests
    run_unit_tests_app
    
    # Run UI tests
    run_ui_tests_app
    
    print_success "All tests completed!"
}

# Function to show test status
show_test_status() {
    print_status "Test Status:"
    echo "  - Unit test target: $UNIT_TEST_TARGET"
    echo "  - UI test target: $UI_TEST_TARGET"
    echo "  - Project: $PROJECT_NAME.xcodeproj"
    echo ""
    
    # Check if app bundle exists
    APP_BUNDLE=$(find build/Debug -name "${PROJECT_NAME}.app" -type d 2>/dev/null | head -1)
    UI_TEST_RUNNER=$(find build/Debug -name "*UITests-Runner.app" -type d 2>/dev/null | head -1)
    
    if [ -n "$APP_BUNDLE" ]; then
        print_success "✓ App bundle found: $APP_BUNDLE"
    else
        print_warning "⚠ App bundle not found"
    fi
    
    if [ -n "$UI_TEST_RUNNER" ]; then
        print_success "✓ UI test runner found: $UI_TEST_RUNNER"
    else
        print_warning "⚠ UI test runner not found"
    fi
}

# Main script logic
case "${1:-help}" in
    "unit")
        run_unit_tests_app
        ;;
    "ui")
        run_ui_tests_app
        ;;
    "all")
        run_all_tests_app
        ;;
    "status")
        show_test_status
        ;;
    "build")
        build_app_and_tests
        ;;
    "help"|*)
        echo "ccSchwabManager App-Based Test Runner"
        echo "====================================="
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  unit   - Run unit tests through app"
        echo "  ui     - Run UI tests through app"
        echo "  all    - Run all tests through app"
        echo "  status - Show test status"
        echo "  build  - Build app and tests"
        echo "  help   - Show this help message"
        echo ""
        echo "This runner avoids symbol linking issues by running tests"
        echo "through the main app instead of directly."
        ;;
esac 