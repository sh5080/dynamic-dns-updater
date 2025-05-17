provider "aws" {
  region = var.region
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_dynamic_dns_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_dynamic_dns_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:*"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "ec2:DescribeInstances"
        ],
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
    }
  }
}

resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = "dns-update-every-minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "lambda"
  arn       = aws_lambda_function.dns_updater.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dns_updater.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}
