#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

#############################################################################
# Packer Template Validation Script
#
# Validates Packer templates with syntax-only checking (no credentials needed)
#############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

echo "======================================"
echo "Packer Template Validation"
echo "======================================"

# Find all Packer templates
if [[ -d "packer" ]]; then
    PACKER_DIR="packer"
elif [[ -d "common-packer" ]]; then
    PACKER_DIR="common-packer"
else
    PACKER_DIR="."
fi

echo "Searching for Packer templates in: $PACKER_DIR"

# Find all .pkr.hcl files
TEMPLATES=$(find "$PACKER_DIR" -name "*.pkr.hcl" -type f 2>/dev/null || true)

if [[ -z "$TEMPLATES" ]]; then
    echo -e "${YELLOW}⚠️  No Packer templates found${NC}"
    exit 0
fi

echo "Found templates:"
echo "$TEMPLATES"
echo ""

# Validate each template
for template in $TEMPLATES; do
    template_dir=$(dirname "$template")
    template_name=$(basename "$template")
    
    echo "Validating: $template"
    
    # Initialize Packer
    echo "  Initializing..."
    if packer init "$template" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Init successful"
    else
        echo -e "  ${RED}✗${NC} Init failed"
        ((FAILED++))
        continue
    fi
    
    # Validate syntax only (no vars needed)
    echo "  Checking syntax..."
    if packer validate -syntax-only "$template" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Syntax valid"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} Syntax invalid"
        packer validate -syntax-only "$template" || true
        ((FAILED++))
    fi
    
    echo ""
done

# Summary
echo "======================================"
echo "Validation Summary"
echo "======================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $FAILED${NC}"
else
    echo -e "Failed: $FAILED"
fi
echo "======================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

echo -e "${GREEN}✅ All $PASSED validations passed${NC}"
exit 0
