#!/usr/bin/env bash
set -euo pipefail

APP_NAME="vibeverse"
BRANCH_NAME="main"
REGION="ap-southeast-2"
ZIP_FILE="frontend.zip"

echo "📦  Zipping frontend directory..."
cd frontend
zip -r "../$ZIP_FILE" . -x "*.zip" -x "*.bak"
cd ..

echo "🚀  Creating AWS Amplify App..."
APP_ID=$(aws amplify create-app --name "$APP_NAME" --region "$REGION" --query 'app.appId' --output text)
echo "    App ID: $APP_ID"

echo "🌿  Creating branch '$BRANCH_NAME'..."
aws amplify create-branch --app-id "$APP_ID" --branch-name "$BRANCH_NAME" --region "$REGION" --no-cli-pager

echo "📤  Initiating Amplify deployment..."
DEPLOY_INFO=$(aws amplify create-deployment --app-id "$APP_ID" --branch-name "$BRANCH_NAME" --region "$REGION")
JOB_ID=$(echo "$DEPLOY_INFO" | jq -r '.jobId')
UPLOAD_URL=$(echo "$DEPLOY_INFO" | jq -r '.zipUploadUrl')

echo "    Job ID: $JOB_ID"

echo "⬆️   Uploading ZIP archive..."
curl -X PUT -H "Content-Type: application/zip" -T "$ZIP_FILE" "$UPLOAD_URL"

echo "⚙️   Starting deployment job..."
aws amplify start-deployment --app-id "$APP_ID" --branch-name "$BRANCH_NAME" --job-id "$JOB_ID" --region "$REGION" --no-cli-pager

echo "⏳  Waiting for deployment to propagate..."
sleep 10

echo ""
echo "══════════════════════════════════════════════════════"
echo "✅  Frontend deployed successfully!"
echo ""
echo "    Live URL: https://$BRANCH_NAME.$APP_ID.amplifyapp.com"
echo "══════════════════════════════════════════════════════"

# Clean up zip
rm -f "$ZIP_FILE"
