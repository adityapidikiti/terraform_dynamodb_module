terraform {
  # terraform test is stable from 1.6; mock_provider (used by the
  # credential-free tests) requires 1.7 or newer.
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
