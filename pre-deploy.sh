#!/bin/bash

# SwarmFarm Paddock Recorder Updater - Pre-deployment Build and Test Script
# This script builds the application and verifies it works locally before deployment

set -e

echo "🚀 Pre-deployment build and test for SwarmFarm Paddock Recorder Updater"

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

# List built files
echo "📁 Built files:"
find dist -type f -name "*.js" | sort

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
    echo "📡 Testing endpoint response:"
    curl -s http://localhost:5000/version | jq . || curl -s http://localhost:5000/version
else
    echo "❌ Local test failed - application not responding"
    kill $APP_PID 2>/dev/null
    exit 1
fi

# Clean up test process
kill $APP_PID 2>/dev/null
echo "🧹 Cleaned up test process"

echo ""
echo "✅ Pre-deployment checks complete!"
echo "🚀 Your application is ready for deployment"
echo ""
echo "Next steps:"
echo "1. Run './deploy.sh' to deploy to Fly.io"
echo "2. Or run 'bun run start' to run locally"
