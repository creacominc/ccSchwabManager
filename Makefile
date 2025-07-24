# ccSchwabManager Makefile
# Provides simple commands for building and testing

.PHONY: help build test ui-test all clean launch info

# Default target
help:
	@echo "ccSchwabManager Build Commands"
	@echo ""
	@echo "Available commands:"
	@echo "  make build           - Build the app for macOS"
	@echo "  make build-ios       - Build the app for iOS Simulator"
	@echo "  make build-ios-device - Build the app for iOS Device"
	@echo "  make test      - Build unit tests and show instructions"
	@echo "  make test-unit - Build unit tests and show instructions"
	@echo "  make test-scheme - Run unit tests (scheme method)"
	@echo "  make ui-test   - Build UI tests and show instructions"
	@echo "  make test-all  - Build all tests and show instructions"
	@echo "  make test-all-scheme - Run all tests (scheme method)"
	@echo "  make all       - Build app and run all tests"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make launch    - Launch the built app"
	@echo "  make info      - Show build configuration"
	@echo "  make configure-testing - Configure testing setup"
	@echo "  make help      - Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  BUILD_CONFIG=Release  - Set build configuration"
	@echo "  DESTINATION=platform=iOS  - Set destination"

# Build the app
build:
	@./build-enhanced.sh build

# Build for iOS Simulator
build-ios:
	@DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro" ./build-enhanced.sh build

# Build for iOS Device
build-ios-device:
	@DESTINATION="generic/platform=iOS" ./build-enhanced.sh build

# Run unit tests
test:
	@echo "Building unit tests and showing instructions..."
	@./run-tests-simple.sh unit

# Run unit tests (alternative method)
test-unit:
	@echo "Building unit tests and showing instructions..."
	@./run-tests-simple.sh unit

# Run unit tests (scheme-based method)
test-scheme:
	@echo "Running unit tests with scheme..."
	@./run-tests.sh unit

# Run UI tests
ui-test:
	@echo "Building UI tests and showing instructions..."
	@./run-tests-simple.sh ui

# Run all tests
test-all:
	@echo "Building all tests and showing instructions..."
	@./run-tests-simple.sh all

# Run all tests (scheme-based method)
test-all-scheme:
	@echo "Running all tests with scheme..."
	@./run-tests.sh all

# Build app and run all tests
all:
	@./build-enhanced.sh all

# Clean build artifacts
clean:
	@./build-enhanced.sh clean

# Launch the app
launch:
	@./build-enhanced.sh launch

# Show build information
info:
	@./build-enhanced.sh info

# Quick build and launch
quick: build launch

# Build for release
release:
	@BUILD_CONFIG=Release ./build-enhanced.sh build

# Run tests with coverage (if available)
test-coverage:
	@echo "Running tests with coverage..."
	@xcodebuild -project ccSchwabManager.xcodeproj \
		-scheme ccSchwabManager \
		-destination 'platform=macOS' \
		-enableCodeCoverage YES \
		test

# Install dependencies (placeholder for future use)
install:
	@echo "No external dependencies to install for this project"

# Setup development environment
setup: install
	@echo "Development environment setup complete"
	@echo "You can now use: make build, make test, etc."

# Configure testing
configure-testing:
	@./configure-testing.sh

# Show project status
status:
	@echo "Project Status:"
	@echo "  - Build script: $(shell test -f build.sh && echo "✓ Available" || echo "✗ Missing")"
	@echo "  - Enhanced script: $(shell test -f build-enhanced.sh && echo "✓ Available" || echo "✗ Missing")"
	@echo "  - Config file: $(shell test -f build-config.json && echo "✓ Available" || echo "✗ Missing")"
	@echo "  - Xcode project: $(shell test -d ccSchwabManager.xcodeproj && echo "✓ Available" || echo "✗ Missing")" 