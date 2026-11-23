#!/usr/bin/env bash
# scripts/bootstrap.sh - Step 1 setup for ShopOps (AWS Learner Lab)
# Recreates the Terraform remote-state backend and the billing budget.
# Run after pasting fresh Learner Lab credentials into ~/.aws/credentials.
# Safe to re-run: existing resources are skipped.

set -u

REGION="us-east-1"
BUCKET="shopops-tfstate-kacimi-2026"
LOCK_TABLE="shopops-tf-lock"
BUDGET_NAME="shopops-budget"
BUDGET_AMOUNT="10"
ALERT_EMAIL="mohamed.kacimi@univ-constantine2.dz"

export AWS_DEFAULT_REGION="$REGION"

echo "==> Checking credentials"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) || {
  echo "ERROR: credentials missing or expired. Paste fresh Learner Lab credentials."
  exit 1
}
echo "Account: $ACCOUNT_ID"

echo "==> Checking LabRole"
aws iam get-role --role-name LabRole --query "Role.Arn" --output text || {
  echo "ERROR: LabRole not found."
  exit 1
}

echo "==> S3 state bucket: $BUCKET"
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket already exists, skipping creation."
else
  # In us-east-1 do NOT pass --create-bucket-configuration
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
fi
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

echo "==> DynamoDB lock table: $LOCK_TABLE"
if aws dynamodb describe-table --table-name "$LOCK_TABLE" >/dev/null 2>&1; then
  echo "Table already exists, skipping creation."
else
  aws dynamodb create-table \
    --table-name "$LOCK_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
  aws dynamodb wait table-exists --table-name "$LOCK_TABLE"
fi

echo "==> Budget: $BUDGET_NAME (\$$BUDGET_AMOUNT/month)"
if aws budgets describe-budget --account-id "$ACCOUNT_ID" \
     --budget-name "$BUDGET_NAME" >/dev/null 2>&1; then
  echo "Budget already exists, skipping creation."
else
  TMP_BUDGET=$(mktemp)
  TMP_NOTIF=$(mktemp)
  cat > "$TMP_BUDGET" <<EOF
{
  "BudgetName": "$BUDGET_NAME",
  "BudgetLimit": { "Amount": "$BUDGET_AMOUNT", "Unit": "USD" },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
EOF
  cat > "$TMP_NOTIF" <<EOF
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      { "SubscriptionType": "EMAIL", "Address": "$ALERT_EMAIL" }
    ]
  }
]
EOF
  aws budgets create-budget --account-id "$ACCOUNT_ID" \
    --budget "file://$TMP_BUDGET" \
    --notifications-with-subscribers "file://$TMP_NOTIF" \
    || echo "WARNING: budget creation failed (may be blocked in Learner Lab). Create it in the console."
  rm -f "$TMP_BUDGET" "$TMP_NOTIF"
fi

echo "==> Verification"
aws s3api get-bucket-versioning --bucket "$BUCKET"
aws dynamodb describe-table --table-name "$LOCK_TABLE" --query "Table.TableStatus"
echo "Bootstrap complete."