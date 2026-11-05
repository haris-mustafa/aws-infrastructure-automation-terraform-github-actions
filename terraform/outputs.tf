# ---------------------------------------------------------------------------
# outputs.tf -- values printed after `terraform apply` (and read by CI)
# ---------------------------------------------------------------------------
output "website_url" {
  description = "Open this in your browser (wait ~2 minutes after first apply)"
  value       = "http://${aws_instance.web.public_ip}"
}

output "api_url" {
  description = "Base URL of the API Gateway"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "uploads_bucket" {
  value = aws_s3_bucket.uploads.bucket
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
