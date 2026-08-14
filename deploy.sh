#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  VibeVerse — One-Click AWS Deploy Script                        ║
# ║  Requires: AWS CLI v2 configured with an IAM user/role          ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

REGION="ap-southeast-2"
FUNCTION_NAME="vibeverse-backend"
ROLE_NAME="vibeverse-lambda-role"
ZIP_FILE="lambda.zip"
FRONTEND_DIR="./frontend"

echo ""
echo "🚀  Deploying VibeVerse to AWS..."
echo "    Region: $REGION"
echo ""

# ── 1. Create IAM Role ────────────────────────────────────────────
echo "▶  Step 1/5 — Creating IAM role..."

TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}'

ROLE_ARN=$(aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --query 'Role.Arn' --output text 2>/dev/null \
  || aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

echo "    Role ARN: $ROLE_ARN"

# Attach policies
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name "vibeverse-inline" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["bedrock:InvokeModel"],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": ["polly:SynthesizeSpeech"],
        "Resource": "*"
      }
    ]
  }'

echo "    Waiting 12s for IAM to propagate..."
sleep 12

# ── 2. Package Lambda ─────────────────────────────────────────────
echo ""
echo "▶  Step 2/5 — Packaging Lambda..."
cd lambda
zip -q "../$ZIP_FILE" lambda_function.py
cd ..
echo "    Created $ZIP_FILE"

# ── 3. Deploy / Update Lambda ─────────────────────────────────────
echo ""
echo "▶  Step 3/5 — Deploying Lambda function..."

EXISTING=$(aws lambda get-function --function-name "$FUNCTION_NAME" \
           --region "$REGION" --query 'Configuration.FunctionName' --output text 2>/dev/null || echo "")

if [ -z "$EXISTING" ]; then
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.12 \
    --role "$ROLE_ARN" \
    --handler lambda_function.handler \
    --zip-file "fileb://$ZIP_FILE" \
    --timeout 30 \
    --memory-size 256 \
    --region "$REGION" \
    --no-cli-pager
  echo "    Lambda created."
else
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$ZIP_FILE" \
    --region "$REGION" \
    --no-cli-pager
  echo "    Lambda updated."
fi

# ── 4. Add / Get Function URL ─────────────────────────────────────
echo ""
echo "▶  Step 4/5 — Setting up Function URL..."

FUNC_URL=$(aws lambda get-function-url-config \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --query 'FunctionUrl' --output text 2>/dev/null || echo "")

if [ -z "$FUNC_URL" ]; then
  FUNC_URL=$(aws lambda create-function-url-config \
    --function-name "$FUNCTION_NAME" \
    --auth-type NONE \
    --cors '{
      "AllowOrigins":["*"],
      "AllowMethods":["*"],
      "AllowHeaders":["Content-Type"],
      "MaxAge":300
    }' \
    --region "$REGION" \
    --query 'FunctionUrl' --output text)

  # Allow public access
  aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id "FunctionURLAllowPublicAccess" \
    --action "lambda:InvokeFunctionUrl" \
    --principal "*" \
    --function-url-auth-type NONE \
    --region "$REGION" \
    --no-cli-pager 2>/dev/null || true
fi

echo "    Function URL: $FUNC_URL"

# ── 5. Patch frontend with Lambda URL ────────────────────────────
echo ""
echo "▶  Step 5/5 — Patching frontend with Lambda URL..."
sed -i.bak "s|YOUR_LAMBDA_FUNCTION_URL_HERE|$FUNC_URL|g" "$FRONTEND_DIR/index.html"
rm -f "$FRONTEND_DIR/index.html.bak"

echo ""
echo "══════════════════════════════════════════════════════"
echo "✅  Backend deployed!"
echo ""
echo "    Function URL:  $FUNC_URL"
echo ""
echo "Next step — Deploy frontend to Amplify:"
echo ""
echo "  Option A (Manual — quickest):"
echo "  1. Zip the frontend/ folder"
echo "  2. Go to: https://console.aws.amazon.com/amplify/"
echo "  3. 'Deploy without Git' → drag & drop the zip"
echo ""
echo "  Option B (CLI — if you have Amplify CLI):"
echo "    cd frontend && amplify publish"
echo ""
echo "══════════════════════════════════════════════════════"
