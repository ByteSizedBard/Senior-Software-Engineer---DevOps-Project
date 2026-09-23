# Active backend for this assessment: LOCAL state (see envs/dev/backend.tf
# for the full rationale). Separate file path from dev keeps the two
# environments' state fully isolated even though both are local here.
terraform {
  backend "local" {
    path = "terraform.prod.tfstate"
  }
}

# --- Production design (documented, NOT active) -----------------------------
#   terraform {
#     backend "s3" {
#       bucket         = "my-company-terraform-state"
#       key            = "almanac/prod/terraform.tfstate"
#       region         = "us-east-1"
#       dynamodb_table = "terraform-locks"
#       encrypt        = true
#     }
#   }
