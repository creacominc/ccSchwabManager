#!/bin/bash

# ccSchwabManager Test Runner
# This script can build and run tests without opening Xcode

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
SCHEME_NAME="ccSchwabManager"
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
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
               -scheme "$SCHEME_NAME" \
               -destination "$DESTINATION" \
               build-for-testing
    print_success "Tests built successfully!"
}

# Function to run unit tests using xctest
run_unit_tests_xctest() {
    print_status "Running unit tests using xctest..."
    
    # Find the test bundle
    TEST_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData -name "${UNIT_TEST_TARGET}.xctest" -type d 2>/dev/null | head -1)
    
    if [ -z "$TEST_BUNDLE" ]; then
        print_error "Test bundle not found. Building tests first..."
        build_tests
        TEST_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData -name "${UNIT_TEST_TARGET}.xctest" -type d 2>/dev/null | head -1)
    fi
    
    if [ -n "$TEST_BUNDLE" ]; then
        print_status "Found test bundle: $TEST_BUNDLE"
        xcrun xctest "$TEST_BUNDLE" -XCTestBundlePath "$TEST_BUNDLE"
    else
        print_error "Could not locate test bundle"
        return 1
    fi
}

# Function to run unit tests using xcodebuild with test action
run_unit_tests_xcodebuild() {
    print_status "Running unit tests using xcodebuild..."
    
    # Try to run tests directly
    if xcodebuild -project "$PROJECT_NAME.xcodeproj" \
                  -scheme "$SCHEME_NAME" \
                  -destination "$DESTINATION" \
                  test \
                  -only-testing:"$UNIT_TEST_TARGET" 2>/dev/null; then
        print_success "Unit tests completed!"
        return 0
    else
        print_warning "Direct test execution failed. Trying alternative method..."
        return 1
    fi
}

# Function to run UI tests
run_ui_tests() {
    print_status "Running UI tests..."
    
    # Try to run UI tests directly
    if xcodebuild -project "$PROJECT_NAME.xcodeproj" \
                  -scheme "$SCHEME_NAME" \
                  -destination "$DESTINATION" \
                  test \
                  -only-testing:"$UI_TEST_TARGET" 2>/dev/null; then
        print_success "UI tests completed!"
        return 0
    else
        print_warning "UI test execution failed. UI tests may need simulator setup."
        return 1
    fi
}

# Function to run all tests
run_all_tests() {
    print_status "Running all tests..."
    
    if xcodebuild -project "$PROJECT_NAME.xcodeproj" \
                  -scheme "$SCHEME_NAME" \
                  -destination "$DESTINATION" \
                  test 2>/dev/null; then
        print_success "All tests completed!"
        return 0
    else
        print_warning "Direct test execution failed. Trying alternative methods..."
        return 1
    fi
}

# Function to show test status
show_test_status() {
    print_status "Test Status:"
    echo "  - Unit test target: $UNIT_TEST_TARGET"
    echo "  - UI test target: $UI_TEST_TARGET"
    echo "  - Project: $PROJECT_NAME.xcodeproj"
    echo "  - Scheme: $SCHEME_NAME"
    echo ""
    
    # Check if tests can be built
    if xcodebuild -project "$PROJECT_NAME.xcodeproj" \
                  -scheme "$SCHEME_NAME" \
                  -destination "$DESTINATION" \
                  build-for-testing > /dev/null 2>&1; then
        print_success "✓ Tests can be built"
    else
        print_error "✗ Tests cannot be built"
    fi
    
    # Check if test bundle exists
    TEST_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData -name "${UNIT_TEST_TARGET}.xctest" -type d 2>/dev/null | head -1)
    if [ -n "$TEST_BUNDLE" ]; then
        print_success "✓ Test bundle found: $TEST_BUNDLE"
    else
        print_warning "⚠ Test bundle not found"
    fi
}

# Main execution
case "${1:-help}" in
    "build")
        build_tests
        ;;
    "unit")
        build_tests
        run_unit_tests_xcodebuild || run_unit_tests_xctest
        ;;
    "ui")
        build_tests
        run_ui_tests
        ;;
    "all")
        build_tests
        run_all_tests || (run_unit_tests_xcodebuild && run_ui_tests)
        ;;
    "status")
        show_test_status
        ;;
    "help"|*)
        echo "ccSchwabManager Test Runner"
        echo "=========================="
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  build   - Build tests only"
        echo "  unit    - Build and run unit tests"
        echo "  ui      - Build and run UI tests"
        echo "  all     - Build and run all tests"
        echo "  status  - Show test status"
        echo "  help    - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 unit     # Run unit tests"
        echo "  $0 ui       # Run UI tests"
        echo "  $0 all      # Run all tests"
        echo ""
        echo "Note: If direct test execution fails, the script will try alternative methods."
        ;;
esac 