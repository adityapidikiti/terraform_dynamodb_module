terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}
