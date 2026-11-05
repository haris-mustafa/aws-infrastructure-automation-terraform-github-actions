# ---------------------------------------------------------------------------
# versions.tf -- which Terraform / provider versions we use + where state lives
# ---------------------------------------------------------------------------
terraform {
  # use_lockfile (S3-native state locking) needs Terraform 1.10 or newer.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive" # zips the Lambda code for us
      version = "~> 2.4"
    }
  }

  # REMOTE STATE: the state file lives in S3 so that your laptop AND GitHub
  # Actions share the same view of your infrastructure.
  # The bucket name is NOT hard-coded; it is passed at init time:
  #   terraform init -backend-config="bucket=<your-state-bucket>"
  # (the bucket is created once by scripts/bootstrap_backend.sh)
  # NOTE: backend blocks cannot use variables, so the region is written here.
  backend "s3" {
    key          = "devops-project/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true # prevents two applies running at the same time
  }
}

provider "aws" {
  region = var.aws_region

  # Every resource automatically gets these tags (handy for cost tracking).
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}

# Used to build globally-unique S3 bucket names.
data "aws_caller_identity" "current" {}
