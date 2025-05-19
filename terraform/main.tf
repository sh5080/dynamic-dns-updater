provider "aws" {
  region  = var.region
  profile = "ndns"
}

# ✅ 기존 Lambda 삭제
resource "null_resource" "delete_existing_lambda" {
  provisioner "local-exec" {
    command = <<EOT
      set -e
      echo "🔍 Checking existing Lambda..."
      if aws lambda get-function --function-name dynamic-dns-updater --region ${var.region} --profile ndns >/dev/null 2>&1; then
        echo "⚠️ Deleting existing Lambda function: dynamic-dns-updater"
        aws lambda delete-function --function-name dynamic-dns-updater --region ${var.region} --profile ndns
      fi
    EOT
  }
}

# ✅ 기존 Role + Inline 정책 삭제
resource "null_resource" "delete_existing_role" {
  provisioner "local-exec" {
    command = <<EOT
      set -e
      echo "🔍 Checking existing IAM Role..."
      if aws iam get-role --role-name lambda_dynamic_dns_role --profile ndns >/dev/null 2>&1; then
        echo "⚠️ Deleting inline policies for role: lambda_dynamic_dns_role"
        aws iam delete-role-policy --role-name lambda_dynamic_dns_role --policy-name lambda_dynamic_dns_policy --profile ndns || true

        echo "⚠️ Deleting IAM role: lambda_dynamic_dns_role"
        aws iam delete-role --role-name lambda_dynamic_dns_role --profile ndns

        echo "⏳ Waiting for role deletion to propagate..."
        sleep 10
      fi
    EOT
  }
}

# ✅ IAM Role
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_dynamic_dns_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow"
    }]
  })
}

# ✅ Inline Policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_dynamic_dns_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["logs:*"],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = ["ec2:DescribeInstances"],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# ✅ Lambda 함수
resource "aws_lambda_function" "dns_updater" {
  function_name = "dynamic-dns-updater"
  handler       = "lambda-function.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  timeout = 10
  environment {
    variables = {
      INSTANCE_ID    = var.instance_id
      HOSTED_ZONE_ID = var.hosted_zone_id
      RECORD_NAME    = var.record_name
      WEBHOOK_URL    = var.webhook_url
    }
  }

  depends_on = [
    null_resource.delete_existing_lambda,
    null_resource.delete_existing_role
  ]
}

# ✅ CloudWatch Event 설정
resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = "dns-update-every-minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "lambda"
  arn       = aws_lambda_function.dns_updater.arn
}

# ✅ Lambda에 EventBridge 권한 부여
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dns_updater.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}

# ✅ 로그 그룹 생성 및 retention 1일로 설정
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.dns_updater.function_name}"
  retention_in_days = 1
}
