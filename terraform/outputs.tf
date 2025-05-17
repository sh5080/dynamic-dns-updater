output "lambda_function_name" {
  value = aws_lambda_function.dns_updater.function_name
}

output "eventbridge_rule" {
  value = aws_cloudwatch_event_rule.every_minute.name
}
