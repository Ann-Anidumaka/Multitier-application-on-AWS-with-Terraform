terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.49.0"
    }
  }
}

# Provider Configuration
provider "aws" {
  region = var.region
}

# Use data sources allow configuration to be
# generic for any region
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}