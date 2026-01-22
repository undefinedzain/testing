#!/bin/bash

# Deploy script untuk VM - simpan ini di VM sebagai /home/merahputih/deploy-testing.sh
# Cara pakai: bash deploy-testing.sh <commit-sha>

set -e

# Load PATH untuk npm dan pm2
export PATH=$PATH:/usr/bin:/usr/local/bin:$HOME/.npm-global/bin
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

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

# Backup current version
if [ -d ".next" ]; then
  echo "💾 Backing up current version..."
  tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz .next public package.json 2>/dev/null || true
fi

# Extract new version
echo "📦 Extracting new version..."
tar -xzf app-latest.tar.gz
rm app-latest.tar.gz

# Restart application with PM2
echo "🔄 Restarting application..."

# Find PM2 binary - check common locations
if [ -f "/usr/local/bin/pm2" ]; then
  PM2_BIN="/usr/local/bin/pm2"
elif [ -f "/usr/bin/pm2" ]; then
  PM2_BIN="/usr/bin/pm2"
elif command -v pm2 &> /dev/null; then
  PM2_BIN="pm2"
else
  echo "❌ PM2 not found. Please install PM2: sudo npm install -g pm2"
  exit 1
fi

echo "Using PM2 at: $PM2_BIN"

if $PM2_BIN describe $PM2_APP_NAME > /dev/null 2>&1; then
  $PM2_BIN restart $PM2_APP_NAME
else
  $PM2_BIN start npm --name $PM2_APP_NAME -- start
  $PM2_BIN save
fi

echo "✅ Deployment completed successfully!"
echo "📊 Application status:"
$PM2_BIN status $PM2_APP_NAME

