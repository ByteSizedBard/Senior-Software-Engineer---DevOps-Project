# Active backend for this assessment: LOCAL state.
#
# The assignment requires separate backend *configuration* per environment,
# not a real, reachable S3 bucket - and no AWS deployment is required at all.
# Pointing this at an S3 bucket that doesn't exist would make plain
# `terraform init` (exactly what reviewers are told to run) fail before
# `validate`/`plan` are ever reached. Local state, with a distinct file per
# environment, satisfies "separate backend config per env" without requiring
# any pre-created AWS resources.
terraform {
  backend "local" {
    path = "terraform.dev.tfstate"
  }
}

# --- Production design (documented, NOT active) -----------------------------
# In a real deployment this would instead be an S3 backend with DynamoDB
# locking, isolated per environment by `key`:
#
#   terraform {
#     backend "s3" {
#       bucket         = "my-company-terraform-state"
#       key            = "almanac/dev/terraform.tfstate"
#       region         = "us-east-1"
#       dynamodb_table = "terraform-locks"
#       encrypt        = true
#     }
#   }
#
# That bucket and DynamoDB table would need to be created out-of-band (they
# can't bootstrap themselves via the same Terraform config that uses them as
# a backend) before switching this file over to it.
