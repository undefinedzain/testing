#!/bin/bash

# Deploy script untuk VM - simpan ini di VM sebagai /home/merahputih/deploy-testing.sh
# Cara pakai: bash deploy-testing.sh <commit-sha>

set -e

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
if pm2 describe $PM2_APP_NAME > /dev/null 2>&1; then
  pm2 restart $PM2_APP_NAME
else
  pm2 start npm --name $PM2_APP_NAME -- start
  pm2 save
fi

echo "✅ Deployment completed successfully!"
echo "📊 Application status:"
pm2 status $PM2_APP_NAME
