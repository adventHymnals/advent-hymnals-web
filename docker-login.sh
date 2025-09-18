#!/bin/bash

# Docker login script for GitHub Container Registry
# This will use the current GitHub CLI token to authenticate Docker with GHCR

echo "🔐 Logging into GitHub Container Registry..."

# Get the current GitHub token from gh CLI
GH_TOKEN=$(gh auth token)

if [ -z "$GH_TOKEN" ]; then
    echo "❌ Error: No GitHub token found. Please run 'gh auth login' first."
    exit 1
fi

# Login to GitHub Container Registry
echo $GH_TOKEN | docker login ghcr.io -u $(gh api user --jq .login) --password-stdin

if [ $? -eq 0 ]; then
    echo "✅ Successfully logged into GitHub Container Registry!"
    echo "You can now run: docker-compose up -d"
else
    echo "❌ Failed to login to GitHub Container Registry"
    exit 1
fi