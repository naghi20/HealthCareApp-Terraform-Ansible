terraform {
  required_version = ">= 1.7.0"
  backend "s3" {
    bucket         = "adi-lab-tfstate-2026"
    key            = "3tier-lab/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
