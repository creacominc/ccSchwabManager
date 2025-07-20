#!/bin/bash

# ccSchwabManager Direct Test Runner
# This script can run tests without needing Xcode scheme configuration

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

# Function to build the app and tests
build_app_and_tests() {
    print_status "Building app and tests..."
    
    # Build the main app
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -target "$PROJECT_NAME" \
               -configuration Debug \
               -destination "$DESTINATION" \
               build
    
    # Build unit tests
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -target "$UNIT_TEST_TARGET" \
               -configuration Debug \
               -destination "$DESTINATION" \
               build
    
    # Build UI tests
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -target "$UI_TEST_TARGET" \
               -configuration Debug \
               -destination "$DESTINATION" \
               build
    
    print_success "Build completed!"
}

# Function to run unit tests using xctest directly
run_unit_tests_direct() {
    print_status "Running unit tests directly..."
    
    # Find the test bundle in the build products (prioritize Debug)
    TEST_BUNDLE=$(find build/Debug -name "${UNIT_TEST_TARGET}.xctest" -type d 2>/dev/null | head -1)
    if [ -z "$TEST_BUNDLE" ]; then
        TEST_BUNDLE=$(find build -name "${UNIT_TEST_TARGET}.xctest" -type d 2>/dev/null | head -1)
    fi
    
    if [ -z "$TEST_BUNDLE" ]; then
        print_error "Test bundle not found. Building first..."
        build_app_and_tests
        TEST_BUNDLE=$(find build/Debug -name "${UNIT_TEST_TARGET}.xctest" -type d 2>/dev/null | head -1)
        if [ -z "$TEST_BUNDLE" ]; then
            TEST_BUNDLE=$(find build -name "${UNIT_TEST_TARGET}.xctest" -type d 2>/dev/null | head -1)
        fi
    fi
    
    if [ -n "$TEST_BUNDLE" ]; then
        print_status "Found test bundle: $TEST_BUNDLE"
        print_status "Running tests with xctest..."
        
        # Run tests using xctest
        xcrun xctest "$TEST_BUNDLE"
        
        print_success "Unit tests completed!"
    else
        print_error "Could not locate test bundle. Trying alternative method..."
        
        # Try running tests by building and running the test target directly
        xcodebuild -project "$PROJECT_NAME.xcodeproj" \
                   -target "$UNIT_TEST_TARGET" \
                   -configuration Debug \
                   -destination "$DESTINATION" \
                   build test
        
        print_success "Unit tests completed via direct build!"
    fi
}

# Function to run UI tests
run_ui_tests_direct() {
    print_status "Running UI tests..."
    
    # Find the UI test bundle
    UI_TEST_BUNDLE=$(find build -name "${UI_TEST_TARGET}.xctest" -type d 2>/dev/null | head -1)
    
    if [ -n "$UI_TEST_BUNDLE" ]; then
        print_status "Found UI test bundle: $UI_TEST_BUNDLE"
        print_status "Running UI tests with xctest..."
        
        # Run UI tests using xctest
        xcrun xctest "$UI_TEST_BUNDLE"
        
        print_success "UI tests completed!"
    else
        print_warning "UI test bundle not found. Building first..."
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
run_all_tests_direct() {
    print_status "Running all tests..."
    
    build_app_and_tests
    
    # Run unit tests
    run_unit_tests_direct
    
    # Run UI tests
    run_ui_tests_direct
    
    print_success "All tests completed!"
}

# Function to show test status
show_test_status() {
    print_status "Test Status:"
    echo "  - Unit test target: $UNIT_TEST_TARGET"
    echo "  - UI test target: $UI_TEST_TARGET"
    echo "  - Project: $PROJECT_NAME.xcodeproj"
    echo ""
    
    # Check if test bundles exist
    UNIT_TEST_BUNDLE=$(find build -name "${UNIT_TEST_TARGET}.xctest" -type d 2>/dev/null | head -1)
    UI_TEST_BUNDLE=$(find build -name "${UI_TEST_TARGET}.xctest" -type d 2>/dev/null | head -1)
    
    if [ -n "$UNIT_TEST_BUNDLE" ]; then
        print_success "✓ Unit test bundle found: $UNIT_TEST_BUNDLE"
    else
        print_warning "⚠ Unit test bundle not found"
    fi
    
    if [ -n "$UI_TEST_BUNDLE" ]; then
        print_success "✓ UI test bundle found: $UI_TEST_BUNDLE"
    else
        print_warning "⚠ UI test bundle not found"
    fi
}

# Function to clean and rebuild
clean_and_build() {
    print_status "Cleaning and rebuilding..."
    
    # Clean build artifacts
    xcodebuild -project "$PROJECT_NAME.xcodeproj" clean
    
    # Rebuild everything
    build_app_and_tests
    
    print_success "Clean build completed!"
}

# Main execution
case "${1:-help}" in
    "build")
        build_app_and_tests
        ;;
    "unit")
        run_unit_tests_direct
        ;;
    "ui")
        run_ui_tests_direct
        ;;
    "all")
        run_all_tests_direct
        ;;
    "clean")
        clean_and_build
        ;;
    "status")
        show_test_status
        ;;
    "help"|*)
        echo "ccSchwabManager Direct Test Runner"
        echo "=================================="
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  build   - Build app and tests"
        echo "  unit    - Run unit tests directly"
        echo "  ui      - Run UI tests directly"
        echo "  all     - Run all tests"
        echo "  clean   - Clean and rebuild everything"
        echo "  status  - Show test status"
        echo "  help    - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 unit     # Run unit tests"
        echo "  $0 ui       # Run UI tests"
        echo "  $0 all      # Run all tests"
        echo "  $0 clean    # Clean and rebuild"
        echo ""
        echo "This script can run tests without needing Xcode scheme configuration."
        ;;
esac 