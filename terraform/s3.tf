# ---------------------------------------------------------------------------
# s3.tf -- bucket that stores uploaded files + SNS notification on upload
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "uploads" {
  # Account ID makes the name globally unique (S3 names are shared by everyone).
  bucket = "${var.project_name}-uploads-${data.aws_caller_identity.current.account_id}"

  # Lets `terraform destroy` delete the bucket even if it contains files.
  force_destroy = true
}

# Block ALL public access: files are private, only presigned URLs can write.
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt everything at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # S3-managed keys (free)
    }
  }
}

# CORS: lets the browser PUT the file directly to S3 from our website.
# TIP: for production replace "*" with your real website origin.
resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

# Every new object under uploads/ -> send an event to the SNS topic -> email.
resource "aws_s3_bucket_notification" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  topic {
    topic_arn     = aws_sns_topic.alerts.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }

  # The topic must allow S3 to publish BEFORE we create the notification.
  depends_on = [aws_sns_topic_policy.alerts]
}
