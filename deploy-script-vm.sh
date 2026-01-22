#!/bin/bash

# Deploy script untuk VM
# Cara pakai: bash deploy-script-vm.sh <commit-sha>

set -e

# Load NVM if exists
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Load common paths
export PATH="$PATH:/usr/local/bin:/usr/bin:$HOME/.npm-global/bin"

# Find PM2 - hardcode path directly
if [ -f "$HOME/.nvm/versions/node/v18.20.8/bin/pm2" ]; then
  PM2_BIN="$HOME/.nvm/versions/node/v18.20.8/bin/pm2"
elif [ -f "/usr/local/bin/pm2" ]; then
  PM2_BIN="/usr/local/bin/pm2"
elif [ -f "/usr/bin/pm2" ]; then
  PM2_BIN="/usr/bin/pm2"
elif which pm2 &> /dev/null; then
  PM2_BIN=$(which pm2)
else
  echo "❌ PM2 not found. Please install PM2"
  exit 1
fi

echo "Using PM2: $PM2_BIN"

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

# Backup and remove old files
echo "💾 Backing up and cleaning old version..."
if [ -d ".next" ]; then
  rm -rf .next.backup 2>/dev/null || true
  mv .next .next.backup
fi

if [ -d "public" ]; then
  rm -rf public.backup 2>/dev/null || true
  mv public public.backup
fi

# Extract new version
echo "📦 Extracting new version..."
tar -xzf app-latest.tar.gz
rm app-latest.tar.gz

# Copy static files to standalone
if [ -d ".next/static" ]; then
  mkdir -p .next/standalone/.next
  cp -r .next/static .next/standalone/.next/static
fi

if [ -d "public" ]; then
  cp -r public .next/standalone/public
fi

# Clean old backups in background
rm -rf .next.backup public.backup &

# Restart application with PM2 (Zero Downtime)
echo "🔄 Reloading application..."

# Start or reload application (zero downtime)
if $PM2_BIN describe $PM2_APP_NAME > /dev/null 2>&1; then
  echo "🔄 Reloading with zero downtime..."
  $PM2_BIN reload $PM2_APP_NAME --update-env
else
  echo "🚀 Starting application in cluster mode..."
  cd .next/standalone
  $PM2_BIN start node --name $PM2_APP_NAME -i 2 -- server.js
fi

$PM2_BIN save

echo "✅ Deployment completed successfully!"
echo "📊 Application status:"
$PM2_BIN status $PM2_APP_NAME