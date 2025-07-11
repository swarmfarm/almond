#!/bin/bash

# SwarmFarm Paddock Recorder Updater Deployment Script for Fly.io
# This script helps deploy the Paddock Recorder updater server to Fly.io

set -e

echo "🚀 Deploying SwarmFarm Paddock Recorder Updater to Fly.io"

# Check if flyctl is installed
if ! command -v flyctl &> /dev/null; then
    echo "❌ flyctl is not installed. Please install it first:"
    echo "   https://fly.io/docs/hands-on/install-flyctl/"
    exit 1
fi

# Check if user is logged in
if ! flyctl auth whoami &> /dev/null; then
    echo "❌ Not logged in to Fly.io. Please run:"
    echo "   flyctl auth login"
    exit 1
fi

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf dist/

# Build the application
echo "🔨 Building application..."
bun run build

# Verify build output
echo "🔍 Verifying build output..."
if [ ! -f "dist/index.js" ]; then
    echo "❌ Build failed: dist/index.js not found"
    exit 1
fi

if [ ! -f "dist/app.js" ]; then
    echo "❌ Build failed: dist/app.js not found"
    exit 1
fi

echo "✅ Build verification complete - all required files present"

# Test the built application locally
echo "🧪 Testing built application..."
echo "Starting application for local test..."
node dist/index.js &
APP_PID=$!

# Wait for app to start
sleep 3

# Test if app is responding
if curl -s http://localhost:5000/version > /dev/null; then
    echo "✅ Local test passed - application is responding"
else
    echo "❌ Local test failed - application not responding"
    kill $APP_PID 2>/dev/null
    exit 1
fi

# Clean up test process
kill $APP_PID 2>/dev/null
echo "🧹 Cleaned up test process"

# Check if secrets are set
echo "🔍 Checking secrets..."
if ! flyctl secrets list | grep -q "TOKEN"; then
    echo "❌ Missing required secrets. Please set them using:"
    echo "   flyctl secrets set TOKEN=your_github_token"
    echo "   flyctl secrets set REPOSITORY=paddock-recorder"
    echo "   flyctl secrets set ACCOUNT=swarmfarm-robotics"
    echo "   flyctl secrets set URL=https://swarmfarm-paddock-recorder-updater.fly.dev"
    echo ""
    echo "Optional secrets:"
    echo "   flyctl secrets set PRE=true  # for pre-release support"
    echo ""
    echo "💡 Your GitHub token needs 'repo' permissions for the repository"
    exit 1
fi

# Deploy to Fly.io
echo "🚀 Deploying to Fly.io..."
flyctl deploy

echo "✅ Deployment complete!"
echo "🌍 Your app is available at: https://swarmfarm-paddock-recorder-updater.fly.dev"
echo ""
echo "📋 Available endpoints:"
echo "   GET /version - Get latest version info"
echo "   GET /download - Auto-detect platform download"
echo "   GET /download/:platform - Platform-specific download"
echo "   GET /update/:platform/:version - Check for updates"
echo "   GET /releases - Get release notes"
