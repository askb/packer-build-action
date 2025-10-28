#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

#############################################################################
# Packer Template Discovery Script
#
# Discovers Packer templates and variable files in the repository
#############################################################################

set -euo pipefail

# Find Packer templates directory
if [[ -d "packer" ]]; then
    PACKER_DIR="packer"
elif [[ -d "common-packer" ]]; then
    PACKER_DIR="common-packer"
elif [[ -d "templates" ]]; then
    PACKER_DIR="templates"
else
    PACKER_DIR="."
fi

echo "Searching for Packer files in: $PACKER_DIR"

# Find templates
TEMPLATES=$(find "$PACKER_DIR" -name "*.pkr.hcl" -type f 2>/dev/null || echo "")

if [[ -z "$TEMPLATES" ]]; then
    echo "No Packer templates found"
    exit 1
fi

echo "Found templates:"
echo "$TEMPLATES"

# Find var files
VAR_FILES=$(find . -name "*.pkrvars.hcl" -o -name "*.auto.pkrvars.hcl" 2>/dev/null || echo "")

if [[ -n "$VAR_FILES" ]]; then
    echo ""
    echo "Found variable files:"
    echo "$VAR_FILES"
fi

# Export for use in action
{
    echo "PACKER_TEMPLATES<<EOF"
    echo "$TEMPLATES"
    echo "EOF"
} >> "$GITHUB_OUTPUT"

if [[ -n "$VAR_FILES" ]]; then
    {
        echo "PACKER_VAR_FILES<<EOF"
        echo "$VAR_FILES"
        echo "EOF"
    } >> "$GITHUB_OUTPUT"
fi
