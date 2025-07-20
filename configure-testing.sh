#!/bin/bash

# ccSchwabManager Test Configuration Script
# This script helps configure the project for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}ccSchwabManager Test Configuration${NC}"
echo "======================================"
echo ""

# Check if we can build tests
echo -e "${YELLOW}Checking test build capability...${NC}"
if xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager -destination 'platform=macOS' build-for-testing > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Tests can be built successfully${NC}"
else
    echo -e "${RED}✗ Test build failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Checking test execution capability...${NC}"
if xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager -destination 'platform=macOS' test > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Tests can be executed successfully${NC}"
    echo ""
    echo "You can now run tests with:"
    echo "  make test"
    echo "  or"
    echo "  xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager -destination 'platform=macOS' test"
else
    echo -e "${RED}✗ Test execution failed - scheme not configured for testing${NC}"
    echo ""
    echo -e "${YELLOW}To fix this, you need to configure the scheme for testing:${NC}"
    echo ""
    echo "1. Open the project in Xcode:"
    echo "   open ccSchwabManager.xcodeproj"
    echo ""
    echo "2. Configure the scheme for testing:"
    echo "   - Go to Product > Scheme > Edit Scheme"
    echo "   - Select 'Test' from the left sidebar"
    echo "   - In the Info tab, check 'ccSchwabManagerTests'"
    echo "   - Click 'Close'"
    echo ""
    echo "3. Then you can run tests with:"
    echo "   make test"
    echo "   or"
    echo "   xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager -destination 'platform=macOS' test"
    echo ""
    echo "Alternatively, you can run tests directly in Xcode with Cmd+U"
fi

echo ""
echo -e "${BLUE}Current project status:${NC}"
echo "  - App builds: ✓"
echo "  - Tests compile: ✓"
echo "  - Tests can be built: ✓"
echo "  - Tests can be executed: $(if xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager -destination 'platform=macOS' test > /dev/null 2>&1; then echo "✓"; else echo "✗ (needs scheme configuration)"; fi)" 