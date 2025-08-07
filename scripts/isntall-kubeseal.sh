#!/bin/bash

set -e

echo "📥 Installing kubeseal CLI..."

# Check if already installed
if command -v kubeseal &> /dev/null; then
    VERSION=$(kubeseal --version 2>&1)
    echo "✅ kubeseal already installed: $VERSION"
    exit 0
fi

# Set version
KUBESEAL_VERSION="0.24.2"

# Download kubeseal
echo "📦 Downloading kubeseal v${KUBESEAL_VERSION}..."
if ! curl -fL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz" -o "kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"; then
    echo "❌ Failed to download kubeseal"
    exit 1
fi

# Extract
echo "🔧 Extracting kubeseal..."
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal

# Install
echo "🔧 Installing kubeseal..."
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Clean up
rm kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal

# Verify installation
if command -v kubeseal &> /dev/null; then
    VERSION=$(kubeseal --version 2>&1)
    echo "✅ kubeseal installed successfully: $VERSION"
else
    echo "❌ kubeseal installation failed"
    exit 1
fi