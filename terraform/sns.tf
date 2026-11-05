# ---------------------------------------------------------------------------
# sns.tf -- notification topic; everything (Lambda, S3, CloudWatch) posts here
# ---------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

# Email subscription. AWS sends a confirmation email: you MUST click the link,
# otherwise no alerts are delivered.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Who is allowed to publish to the topic?
#  - S3 (upload notifications), only from OUR bucket
#  - CloudWatch alarms, only from OUR account
# (The Lambda role publishes through its own IAM policy in lambda.tf.)
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3Publish"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.alerts.arn
        Condition = {
          ArnLike = { "aws:SourceArn" = aws_s3_bucket.uploads.arn }
        }
      },
      {
        Sid       = "AllowCloudWatchPublish"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.alerts.arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      }
    ]
  })
}
