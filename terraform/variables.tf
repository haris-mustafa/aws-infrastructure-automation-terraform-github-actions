# ---------------------------------------------------------------------------
# variables.tf -- the "settings" of the project. Override in terraform.tfvars
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy to (ap-south-1 = Mumbai)"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used in the name of every resource"
  type        = string
  default     = "devops-demo"
}

variable "alert_email" {
  description = "Email address that receives SNS alerts (you must confirm the subscription email)"
  type        = string
}

variable "instance_type" {
  description = "EC2 size. t3.micro is Free-Tier eligible on most accounts"
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "IP range of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "visit_milestone" {
  description = "Send an SNS alert every N visits"
  type        = number
  default     = 10
}
