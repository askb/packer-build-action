#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

#############################################################################
# Packer Build Script
#
# Executes Packer build with proper configuration
#############################################################################

set -euo pipefail

# Required parameters
TEMPLATE="${PACKER_TEMPLATE:-}"
VARS_FILE="${PACKER_VARS_FILE:-}"
BASTION_IP="${BASTION_IP:-}"

if [[ -z "$TEMPLATE" ]]; then
    echo "❌ Error: PACKER_TEMPLATE environment variable is required"
    exit 1
fi

if [[ -z "$VARS_FILE" ]]; then
    echo "❌ Error: PACKER_VARS_FILE environment variable is required"
    exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
    echo "❌ Error: Template file not found: $TEMPLATE"
    exit 1
fi

if [[ ! -f "$VARS_FILE" ]]; then
    echo "❌ Error: Variables file not found: $VARS_FILE"
    exit 1
fi

echo "======================================="
echo "Packer Build"
echo "======================================="
echo "Template: $TEMPLATE"
echo "Vars File: $VARS_FILE"
echo "Bastion IP: ${BASTION_IP:-<not set>}"
echo "======================================="

# Initialize Packer plugins
echo "🔧 Initializing Packer..."
packer init "$TEMPLATE"

# Build command array
PACKER_ARGS=(build)

# Add cloud environment if exists
if [[ -f "cloud-env.json" ]]; then
    PACKER_ARGS+=(-var-file=cloud-env.json)
fi

# Add variables file
PACKER_ARGS+=(-var-file="$VARS_FILE")

# Add bastion host if provided (passed as ssh_proxy_host for Tailscale)
if [[ -n "$BASTION_IP" ]]; then
    PACKER_ARGS+=(-var=ssh_proxy_host="$BASTION_IP")
fi

# Add template
PACKER_ARGS+=("$TEMPLATE")

echo "🔨 Executing: packer ${PACKER_ARGS[*]}"
echo ""

# Execute build with real-time output streaming
if packer "${PACKER_ARGS[@]}"; then
    echo ""
    echo "======================================="
    echo "✅ Build completed successfully"
    echo "======================================="

    # Try to extract image name from output
    # This is cloud-provider specific logic
    if [[ -f "manifest.json" ]]; then
        IMAGE_NAME=$(jq -r '.builds[0].artifact_id' manifest.json 2>/dev/null || echo "unknown")
        echo "IMAGE_NAME=$IMAGE_NAME" >> "$GITHUB_OUTPUT"
    fi

    exit 0
else
    echo ""
    echo "======================================="
    echo "❌ Build failed"
    echo "======================================="
    exit 1
fi
