#!/bin/bash

# Script to run tests for the refactored Recommended Orders components
# This script helps verify that the refactoring maintains all functionality

echo "🧪 Running tests for refactored Recommended Orders components..."
echo "================================================================"

# Check if we're in the right directory
if [ ! -f "ccSchwabManager.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

echo "📁 Project structure verified"
echo ""

# Run unit tests for business logic
echo "🔬 Running OrderRecommendationService unit tests..."
xcodebuild test \
    -scheme ccSchwabManager \
    -destination 'platform=macOS' \
    -only-testing:ccSchwabManagerTests/OrderRecommendationServiceTests \
    | grep -E "(PASS|FAIL|error:|warning:)" || true

echo ""

# Run unit tests for view model
echo "🧩 Running OrderRecommendationViewModel unit tests..."
xcodebuild test \
    -scheme ccSchwabManager \
    -destination 'platform=macOS' \
    -only-testing:ccSchwabManagerTests/OrderRecommendationViewModelTests \
    | grep -E "(PASS|FAIL|error:|warning:)" || true

echo ""

# Run UI tests (if available)
echo "🖥️  Running UI tests for refactored view..."
xcodebuild test \
    -scheme ccSchwabManager \
    -destination 'platform=macOS' \
    -only-testing:ccSchwabManagerUITests/RefactoredRecommendedOCOOrdersSectionUITests \
    | grep -E "(PASS|FAIL|error:|warning:)" || true

echo ""
echo "================================================================"
echo "✅ Test execution completed!"
echo ""
echo "📋 Summary:"
echo "   - Business logic tests: OrderRecommendationService"
echo "   - State management tests: OrderRecommendationViewModel"
echo "   - UI tests: RefactoredRecommendedOCOOrdersSection"
echo ""
echo "💡 To run all tests at once, use:"
echo "   xcodebuild test -scheme ccSchwabManager -destination 'platform=macOS'"
echo ""
echo "🔍 To run tests in Xcode:"
echo "   - Open ccSchwabManager.xcodeproj"
echo "   - Select Product > Test (⌘U)"
echo "   - View results in Test Navigator"
