#!/usr/bin/env bash
set -euo pipefail

API_NAME="vibeverse-api"
FUNCTION_NAME="vibeverse-backend"
REGION="ap-southeast-2"
ACCOUNT_ID="052717076349"
LAMBDA_ARN="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$FUNCTION_NAME"

echo "🌐  Creating API Gateway HTTP API..."
API_INFO=$(aws apigatewayv2 create-api \
  --name "$API_NAME" \
  --protocol-type HTTP \
  --region "$REGION")

API_ID=$(echo "$API_INFO" | jq -r '.ApiId')
API_ENDPOINT=$(echo "$API_INFO" | jq -r '.ApiEndpoint')

echo "    API ID: $API_ID"
echo "    Endpoint: $API_ENDPOINT"

echo "🔗  Creating Lambda integration..."
INTEGRATION_INFO=$(aws apigatewayv2 create-integration \
  --api-id "$API_ID" \
  --integration-type AWS_PROXY \
  --integration-uri "$LAMBDA_ARN" \
  --payload-format-version "2.0" \
  --region "$REGION")

INTEGRATION_ID=$(echo "$INTEGRATION_INFO" | jq -r '.IntegrationId')
echo "    Integration ID: $INTEGRATION_ID"

echo "🛣️  Creating route ANY / ..."
aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "ANY /" \
  --target "integrations/$INTEGRATION_ID" \
  --region "$REGION" \
  --no-cli-pager

echo "🔑  Adding permissions to Lambda..."
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "AllowAPIGatewayInvoke-vibeverse" \
  --action "lambda:InvokeFunction" \
  --principal "apigateway.amazonaws.com" \
  --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/*" \
  --region "$REGION" \
  --no-cli-pager 2>/dev/null || true

echo "📝  Updating frontend index.html with new API endpoint..."
# First restore a clean template index.html if we modified it
# Or just replace the old Function URL line with the new API endpoint
# To be safe, we just substitute the lambda-url string with the API endpoint.
# The current URL in index.html is https://76jfv53leby63d6m7fb2z76vwa0hibmn.lambda-url.ap-southeast-2.on.aws/
sed -i.bak "s|https://76jfv53leby63d6m7fb2z76vwa0hibmn.lambda-url.ap-southeast-2.on.aws/|$API_ENDPOINT/|g" frontend/index.html
rm -f frontend/index.html.bak

echo "📦  Re-packaging frontend..."
cd frontend
zip -r ../frontend.zip . -x "*.zip" -x "*.bak"
cd ..

# Get existing Amplify App ID from the previous run
# We know the App ID is "d3dtpnmjar5d19" from the logs.
APP_ID="d3dtpnmjar5d19"
BRANCH_NAME="main"

echo "📤  Uploading new package to Amplify app $APP_ID..."
DEPLOY_INFO=$(aws amplify create-deployment --app-id "$APP_ID" --branch-name "$BRANCH_NAME" --region "$REGION")
JOB_ID=$(echo "$DEPLOY_INFO" | jq -r '.jobId')
UPLOAD_URL=$(echo "$DEPLOY_INFO" | jq -r '.zipUploadUrl')

echo "    Job ID: $JOB_ID"
curl -X PUT -H "Content-Type: application/zip" -T "frontend.zip" "$UPLOAD_URL"

echo "⚙️   Starting deployment..."
aws amplify start-deployment --app-id "$APP_ID" --branch-name "$BRANCH_NAME" --job-id "$JOB_ID" --region "$REGION" --no-cli-pager

echo ""
echo "══════════════════════════════════════════════════════"
echo "✅  Successfully deployed with API Gateway!"
echo ""
echo "    New API Endpoint: $API_ENDPOINT/"
echo "    App Live URL:     https://$BRANCH_NAME.$APP_ID.amplifyapp.com"
echo "══════════════════════════════════════════════════════"
rm -f frontend.zip
