# ---------------------------------------------------------------------------
# cloudwatch.tf -- monitoring: alarms that email you via SNS + a dashboard
# ---------------------------------------------------------------------------

# Alarm if either Lambda function throws any error in a 5-minute window.
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = {
    counter = aws_lambda_function.counter.function_name
    upload  = aws_lambda_function.upload.function_name
  }

  alarm_name          = "${var.project_name}-${each.key}-errors"
  alarm_description   = "Lambda ${each.value} reported errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = each.value }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching" # no traffic = no alarm

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# Alarm if the web server CPU stays above 80% for 10 minutes.
resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${var.project_name}-ec2-high-cpu"
  alarm_description   = "EC2 CPU above 80%"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = aws_instance.web.id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# One-page dashboard: Lambda invocations/errors + EC2 CPU
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda invocations"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.counter.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.upload.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda errors"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.counter.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.upload.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "EC2 CPU %"
          region  = var.aws_region
          stat    = "Average"
          period  = 300
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web.id]]
        }
      }
    ]
  })
}
