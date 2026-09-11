terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  backend "s3" {
    bucket         = "resilientvote-tfstate-prod"
    key            = "voting-engine-v2/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "resilientvote-tflocks"
  }
}
