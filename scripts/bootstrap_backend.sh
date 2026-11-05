#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# bootstrap_backend.sh -- run ONCE before your first `terraform init`.
#
# Creates the S3 bucket that stores Terraform's state file.
# (Chicken-and-egg: Terraform can't create the bucket that holds its own
#  state, so we create it with the AWS CLI instead.)
#
# Usage:  ./scripts/bootstrap_backend.sh
# Needs:  AWS CLI configured (`aws configure`) with admin-like permissions.
# ---------------------------------------------------------------------------
set -euo pipefail

REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="devops-demo-tfstate-${ACCOUNT_ID}"   # unique per AWS account

echo "Creating state bucket: ${BUCKET} in ${REGION}"

# Regions other than us-east-1 require a LocationConstraint.
if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "Bucket already exists, skipping creation."
else
  aws s3api create-bucket \
    --bucket "${BUCKET}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}"
fi

# Keep old versions of the state file (lets you recover from mistakes).
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" --versioning-configuration Status=Enabled

# Encrypt at rest + never allow public access.
aws s3api put-bucket-encryption --bucket "${BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo
echo "Done. Your state bucket name is:"
echo "  ${BUCKET}"
echo
echo "Next:"
echo "  cd terraform && terraform init -backend-config=\"bucket=${BUCKET}\""
echo "  and add the bucket name as the GitHub secret TF_STATE_BUCKET"
