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

resource "aws_db_instance" "example" {
  identifier_prefix   = "terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t2.micro"
  skip_final_snapshot = true
  db_name             = var.db_name

  # WARNING: Storing credentials directly in variables ties secrets to the codebase.
  # Make sure var.db_username and var.db_password come from a secure channel
  # (e.g., environment variables injected by a per-user secrets manager) so that
  # you never commit plain-text secrets to version control.
  username = var.db_username
  password = var.db_password
}
