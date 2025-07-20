#!/bin/bash

# ccSchwabManager xcodebuild Test Runner
# This script uses xcodebuild to run tests with a different approach

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

# Function to run unit tests using xcodebuild
run_unit_tests_xcodebuild() {
    print_status "Running unit tests with xcodebuild..."
    
    # Build and test in one command
    print_status "Building and running unit tests..."
    
    # Use xcodebuild to build and test the unit test target
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -target "$UNIT_TEST_TARGET" \
               -configuration Debug \
               -destination "$DESTINATION" \
               build test
    
    print_success "Unit tests completed!"
}

# Function to run UI tests using xcodebuild
run_ui_tests_xcodebuild() {
    print_status "Running UI tests with xcodebuild..."
    
    # Build and test in one command
    print_status "Building and running UI tests..."
    
    # Use xcodebuild to build and test the UI test target
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -target "$UI_TEST_TARGET" \
               -configuration Debug \
               -destination "$DESTINATION" \
               build test
    
    print_success "UI tests completed!"
}

# Function to run all tests
run_all_tests_xcodebuild() {
    print_status "Running all tests with xcodebuild..."
    
    # Run unit tests
    run_unit_tests_xcodebuild
    
    # Run UI tests
    run_ui_tests_xcodebuild
    
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

# Function to build tests only
build_tests() {
    print_status "Building tests..."
    
    # Build unit tests
    print_status "Building unit tests..."
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -target "$UNIT_TEST_TARGET" \
               -configuration Debug \
               -destination "$DESTINATION" \
               build
    
    # Build UI tests
    print_status "Building UI tests..."
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -target "$UI_TEST_TARGET" \
               -configuration Debug \
               -destination "$DESTINATION" \
               build
    
    print_success "Tests built successfully!"
}

# Main script logic
case "${1:-help}" in
    "unit")
        run_unit_tests_xcodebuild
        ;;
    "ui")
        run_ui_tests_xcodebuild
        ;;
    "all")
        run_all_tests_xcodebuild
        ;;
    "status")
        show_test_status
        ;;
    "build")
        build_tests
        ;;
    "help"|*)
        echo "ccSchwabManager xcodebuild Test Runner"
        echo "====================================="
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  unit   - Run unit tests with xcodebuild"
        echo "  ui     - Run UI tests with xcodebuild"
        echo "  all    - Run all tests with xcodebuild"
        echo "  status - Show test status"
        echo "  build  - Build tests only"
        echo "  help   - Show this help message"
        echo ""
        echo "This runner uses xcodebuild to build and test in one command,"
        echo "avoiding symbol linking issues."
        ;;
esac 