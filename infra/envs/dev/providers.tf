terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # This is a plan-only assessment - no real AWS account is used. The AWS
  # provider normally performs credential + STS "who am I" discovery even
  # during `plan`, which fails against the placeholder credentials the CI
  # workflow sets (AWS_ACCESS_KEY_ID=test / AWS_SECRET_ACCESS_KEY=test).
  # These flags explicitly disable that discovery so `plan` works with no
  # real AWS access, rather than relying on dummy credentials "happening" to
  # be enough.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

locals {
  name_prefix = "${var.project_name}-dev"
  tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
