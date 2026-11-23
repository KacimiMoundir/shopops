terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "shopops-tfstate-kacimi-2026"
    key            = "shopops/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "shopops-tf-lock"
    encrypt        = true
  }
}