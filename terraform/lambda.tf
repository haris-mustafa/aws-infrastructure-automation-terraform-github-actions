# ---------------------------------------------------------------------------
# lambda.tf -- IAM role, packaging, and the two Lambda functions
# ---------------------------------------------------------------------------

# Zip the folder app/lambda. Terraform re-uploads only when the code changes.
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../app/lambda"
  output_path = "${path.module}/build/lambda.zip"
  excludes    = ["__pycache__"]
}

# --- IAM: what the Lambda functions are allowed to do (least privilege) ---
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Permission to write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Our own narrow permissions: one table, one topic, one bucket path
resource "aws_iam_role_policy" "lambda_app" {
  name = "${var.project_name}-lambda-app"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.visits.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.alerts.arn
      },
      {
        # Needed so the presigned URL we create is allowed to write to S3
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.uploads.arn}/uploads/*"
      }
    ]
  })
}

# --- CloudWatch log groups (created first so we control retention) ---
resource "aws_cloudwatch_log_group" "counter" {
  name              = "/aws/lambda/${var.project_name}-visitor-counter"
  retention_in_days = 7 # keep logs a week to save money
}

resource "aws_cloudwatch_log_group" "upload" {
  name              = "/aws/lambda/${var.project_name}-upload-url"
  retention_in_days = 7
}

# --- Function 1: visitor counter ---
resource "aws_lambda_function" "counter" {
  function_name = "${var.project_name}-visitor-counter"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "visitor_counter.handler" # file name . function name

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visits.name
      TOPIC_ARN  = aws_sns_topic.alerts.arn
      MILESTONE  = tostring(var.visit_milestone)
    }
  }

  depends_on = [aws_cloudwatch_log_group.counter]
}

# --- Function 2: presigned upload URL ---
resource "aws_lambda_function" "upload" {
  function_name = "${var.project_name}-upload-url"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "upload_url.handler"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.uploads.bucket
    }
  }

  depends_on = [aws_cloudwatch_log_group.upload]
}
