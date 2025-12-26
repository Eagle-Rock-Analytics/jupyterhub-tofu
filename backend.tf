# Backend configuration for remote state storage
# Actual values are provided via -backend-config=environments/<env>/backend.tfvars

terraform {
  backend "s3" {
    # These values are configured via backend.tfvars:
    # - bucket
    # - key
    # - region
    # - dynamodb_table
    # - encrypt
  }
}
