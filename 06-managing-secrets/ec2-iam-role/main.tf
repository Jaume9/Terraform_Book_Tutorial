# This Terraform configuration demonstrates how to launch an EC2 instance with an attached IAM role and instance profile,
# granting the EC2 instance administrative privileges for EC2 resources ("ec2:*"). The setup includes:
# - Specifying the required Terraform and AWS provider versions.
# - Configuring the AWS provider to operate in the "us-east-2" region.
# - Creating a new aws_instance, specifying both its AMI and instance type.
# - Creating an IAM role, along with an associated policy document that allows EC2 to assume this role.
# - Attaching an inline policy granting full EC2 permissions to the role.
# - Generating an instance profile that is required for EC2 to use the IAM role.
# This example highlights the recommended practice of locking down instance metadata service (IMDS) access
# to enhance security after an instance boots (see Chapter 6).

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

resource "aws_instance" "example" {
  ami           = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"

  # Attach the instance profile
  iam_instance_profile = aws_iam_instance_profile.instance.name

  # Harden the instance metadata endpoint in user data or AMI config so only
  # the processes that really need the IAM role can read tokens (see Chapter 6
  # recommendation about locking down IMDS or disabling it after boot).
}

# Create an IAM role
resource "aws_iam_role" "instance" {
  name_prefix        = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Allow the IAM role to be assumed by EC2 instances
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Attach the EC2 admin permissions to the IAM role
resource "aws_iam_role_policy" "example" {
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.ec2_admin_permissions.json
}

# Create an IAM policy that grants EC2 admin permissions
data "aws_iam_policy_document" "ec2_admin_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:*"]
    resources = ["*"]
  }
}

# Create an instance profile with the IAM role attached
resource "aws_iam_instance_profile" "instance" {
  role = aws_iam_role.instance.name
}
