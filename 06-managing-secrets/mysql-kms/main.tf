terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

data "aws_kms_secrets" "creds" {
  secret {
    name    = "db"
    payload = file("${path.module}/db-creds.yml.encrypted")
  }

  # NOTE: aws_kms_secrets decrypts data only in memory. Keep the encrypted file
  # (`db-creds.yml.encrypted`) in version control, but ensure the plain-text
  # source material (`db-creds.yml`) never touches git. Rotate the CMK regularly
  # if multiple services share it, and audit IAM permissions for decrypt calls.
}

locals {
  db_creds = yamldecode(data.aws_kms_secrets.creds.plaintext["db"])
}

resource "aws_db_instance" "example" {
  identifier_prefix   = "terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t2.micro"
  skip_final_snapshot = true
  db_name             = var.db_name

  # Pass the secrets to the resource. Terraform state now contains these values,
  # so make sure you encrypt the state file (e.g., S3 SSE + DynamoDB KMS) and
  # restrict who can read it, as recommended in Chapter 6.
  username = local.db_creds.username
  password = local.db_creds.password
}
