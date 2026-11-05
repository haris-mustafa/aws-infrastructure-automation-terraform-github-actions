"""
upload_url.py  --  Lambda function behind  GET /upload-url?filename=photo.png

What it does:
  Creates a short-lived "presigned URL". The browser uploads the file
  DIRECTLY to S3 with that URL, so the file never passes through Lambda
  (cheaper, faster, no 6 MB Lambda payload limit).

Once the file lands in S3, S3 itself sends an SNS notification
(configured in terraform/s3.tf), so you get an email for each upload.
"""
import json
import os
import re
import uuid

import boto3
from botocore.config import Config

BUCKET = os.environ["BUCKET_NAME"]
EXPIRES_SECONDS = 300  # link is valid for 5 minutes only

# s3v4 + virtual-host addressing gives a regional URL that works with the
# browser CORS rules on the bucket. AWS_REGION is set automatically by Lambda.
s3 = boto3.client(
    "s3",
    region_name=os.environ.get("AWS_REGION"),
    config=Config(signature_version="s3v4", s3={"addressing_style": "virtual"}),
)


def _response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def _safe_name(name):
    """Keep only letters, digits, dot, dash, underscore (blocks '../' tricks)."""
    name = re.sub(r"[^A-Za-z0-9._-]", "_", name)  # replace odd characters
    name = re.sub(r"\.{2,}", ".", name)           # collapse '..' into '.'
    return name.lstrip(".")[:100] or "file"       # no hidden/dot-only names


def handler(event, context):
    params = event.get("queryStringParameters") or {}
    filename = params.get("filename")
    if not filename:
        return _response(400, {"error": "Missing ?filename= query parameter"})

    # A random prefix means two people uploading "a.png" never overwrite each other.
    key = f"uploads/{uuid.uuid4().hex[:8]}-{_safe_name(filename)}"

    url = s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": BUCKET, "Key": key},
        ExpiresIn=EXPIRES_SECONDS,
    )
    return _response(200, {"uploadUrl": url, "key": key})
