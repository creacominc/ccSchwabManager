#!/bin/bash

# ccSchwabManager Simple Test Runner
# This script builds tests and provides instructions for running them

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

# Function to build tests
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

# Function to show instructions
show_instructions() {
    echo ""
    echo "=========================================="
    echo "HOW TO RUN TESTS IN XCODE"
    echo "=========================================="
    echo ""
    echo "Since the scheme isn't configured for testing, you need to run tests in Xcode:"
    echo ""
    echo "1. Open the project in Xcode:"
    echo "   open ccSchwabManager.xcodeproj"
    echo ""
    echo "2. Configure the scheme for testing:"
    echo "   - Go to Product > Scheme > Edit Scheme"
    echo "   - Select 'Test' from the left sidebar"
    echo "   - Check 'ccSchwabManagerTests' in the Info tab"
    echo "   - Click 'Close'"
    echo ""
    echo "3. Run tests in Xcode:"
    echo "   - Press Cmd+U to run tests"
    echo "   - Or click Product > Test"
    echo ""
    echo "Alternatively, you can run tests from the command line after configuring the scheme:"
    echo "   xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager -destination 'platform=macOS' test"
    echo ""
}

# Function to run unit tests (build only)
run_unit_tests_simple() {
    print_status "Building unit tests..."
    
    # Build unit tests
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -target "$UNIT_TEST_TARGET" \
               -configuration Debug \
               -destination "$DESTINATION" \
               build
    
    print_success "Unit tests built successfully!"
    show_instructions
}

# Function to run UI tests (build only)
run_ui_tests_simple() {
    print_status "Building UI tests..."
    
    # Build UI tests
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -target "$UI_TEST_TARGET" \
               -configuration Debug \
               -destination "$DESTINATION" \
               build
    
    print_success "UI tests built successfully!"
    show_instructions
}

# Function to run all tests (build only)
run_all_tests_simple() {
    print_status "Building all tests..."
    
    # Build unit tests
    run_unit_tests_simple
    
    # Build UI tests
    run_ui_tests_simple
    
    print_success "All tests built successfully!"
    show_instructions
}

# Main script logic
case "${1:-help}" in
    "unit")
        run_unit_tests_simple
        ;;
    "ui")
        run_ui_tests_simple
        ;;
    "all")
        run_all_tests_simple
        ;;
    "status")
        show_test_status
        ;;
    "build")
        build_tests
        ;;
    "instructions")
        show_instructions
        ;;
    "help"|*)
        echo "ccSchwabManager Simple Test Runner"
        echo "================================="
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  unit         - Build unit tests and show instructions"
        echo "  ui           - Build UI tests and show instructions"
        echo "  all          - Build all tests and show instructions"
        echo "  status       - Show test status"
        echo "  build        - Build tests only"
        echo "  instructions - Show how to run tests in Xcode"
        echo "  help         - Show this help message"
        echo ""
        echo "This runner builds tests and provides instructions for"
        echo "running them in Xcode, avoiding symbol linking issues."
        ;;
esac 