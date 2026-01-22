#!/bin/bash

# Deploy script untuk VM
# Cara pakai: bash deploy-script-vm.sh <commit-sha>

set -e

# Load NVM if exists
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Load common paths
export PATH="$PATH:/usr/local/bin:/usr/bin:$HOME/.npm-global/bin"

COMMIT_SHA=$1
APP_NAME="testing-app"
BUCKET_NAME="kopdes-merah-putih"
DEPLOY_DIR="/home/merahputih/testing"
PM2_APP_NAME="testing-nextjs"

echo "🚀 Starting deployment for commit: $COMMIT_SHA"

# Create deploy directory if not exists
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

# Download latest build from GCS
echo "📥 Downloading build from Cloud Storage..."
gsutil cp gs://$BUCKET_NAME/testing-app/app-$COMMIT_SHA.tar.gz ./app-latest.tar.gz

# Stop PM2 app if running
echo "⏸️  Stopping application..."
if $PM2_BIN describe $PM2_APP_NAME > /dev/null 2>&1; then
  $PM2_BIN stop $PM2_APP_NAME
fi

# Backup current version
if [ -d ".next" ]; then
  echo "💾 Backing up current version..."
  tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz .next public package.json 2>/dev/null || true
fi

# Clean old files
echo "🧹 Cleaning old build..."
rm -rf .next node_modules

# Extract new version
echo "📦 Extracting new version..."
tar -xzf app-latest.tar.gz
rm app-latest.tar.gz

# Restart application with PM2
echo "🔄 Restarting application..."

# Find PM2 - try multiple methods
if command -v pm2 &> /dev/null; then
  PM2_BIN="pm2"
elif [ -f "$HOME/.nvm/versions/node/v18.20.8/bin/pm2" ]; then
  PM2_BIN="$HOME/.nvm/versions/node/v18.20.8/bin/pm2"
elif [ -f "/usr/local/bin/pm2" ]; then
  PM2_BIN="/usr/local/bin/pm2"
elif [ -f "/usr/bin/pm2" ]; then
  PM2_BIN="/usr/bin/pm2"
else
  echo "❌ PM2 not found. Please install PM2"
  exit 1
fi

echo "Using PM2: $PM2_BIN"

# Start or restart application
if $PM2_BIN describe $PM2_APP_NAME > /dev/null 2>&1; then
  $PM2_BIN restart $PM2_APP_NAME
else
  $PM2_BIN start npm --name $PM2_APP_NAME -- start
fi

$PM2_BIN save

echo "✅ Deployment completed successfully!"
echo "📊 Application status:"
$PM2_BIN status $PM2_APP_NAME

