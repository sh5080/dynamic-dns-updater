#!/bin/bash

set -e

TFVARS_FILE="terraform/variables.auto.tfvars"

# ======== 1. 기존 tfvars 확인 및 선택 ==========
if [ -f "$TFVARS_FILE" ]; then
  echo "⚠️ Found existing $TFVARS_FILE"
  read -p "Do you want to reuse this file? (y/n): " reuse
  if [[ "$reuse" =~ ^[Yy]$ ]]; then
    echo "✅ Reusing existing $TFVARS_FILE"
  else
    echo "📝 Re-enter values:"
    read -p "Enter EC2 Instance ID: " INSTANCE_ID
    read -p "Enter Hosted Zone ID: " HOSTED_ZONE_ID
    read -p "Enter DNS Record Name (e.g., sub.example.com.): " RECORD_NAME
    read -p "Enter Webhook URL: " WEBHOOK_URL

    echo "Generating $TFVARS_FILE..."
    cat > $TFVARS_FILE <<EOF
instance_id = "${INSTANCE_ID}"
hosted_zone_id = "${HOSTED_ZONE_ID}"
record_name = "${RECORD_NAME}"
webhook_url = "${WEBHOOK_URL}"
EOF
  fi
else
  echo "📝 No tfvars found. Enter values:"
  read -p "Enter EC2 Instance ID: " INSTANCE_ID
  read -p "Enter Hosted Zone ID: " HOSTED_ZONE_ID
  read -p "Enter DNS Record Name (e.g., sub.example.com.): " RECORD_NAME
  read -p "Enter Webhook URL: " WEBHOOK_URL

  echo "Generating $TFVARS_FILE..."
  cat > $TFVARS_FILE <<EOF
instance_id = "${INSTANCE_ID}"
hosted_zone_id = "${HOSTED_ZONE_ID}"
record_name = "${RECORD_NAME}"
webhook_url = "${WEBHOOK_URL}"
EOF
fi

# ======== 2. Lambda 패키징 ==========
echo "📦 Building Lambda package..."
cd lambda || exit 1

rm -rf package ../terraform/lambda.zip
pip3 install --target ./package -r requirements.txt

cd package
zip -qr ../lambda.zip .
cd ..
zip -g lambda.zip lambda-function.py
mv lambda.zip ../terraform/

cd ../terraform

# ======== 3. Terraform 초기화 ==========
echo "⚙️ Initializing Terraform..."
terraform init

# ======== 4. 로그 그룹 Import (에러 무시) ==========
# 이미 import된 경우 에러 발생하므로 무시하고 진행
echo "📥 Importing existing CloudWatch Log Group (if not already imported)..."
terraform import aws_cloudwatch_log_group.lambda_log_group /aws/lambda/dynamic-dns-updater || true

# ======== 5. Terraform 배포 ==========
echo "🚀 Deploying with Terraform..."
terraform apply -auto-approve

echo "✅ Deployment complete."
