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

# ============================================================================
# SAFE REFACTORING EXAMPLE WITH MOVED BLOCKS
# ============================================================================
# This example demonstrates how to refactor Terraform code without causing downtime.
#
# PROBLEM:
# If we simply rename a resource identifier from "instance" to "cluster_instance",
# Terraform will interpret this as:
#   1. Delete the aws_security_group.instance resource
#   2. Create a new aws_security_group.cluster_instance resource
#
# This would cause DOWNTIME because:
#   - The old security group would be deleted first
#   - Servers would lose their security rules
#   - Network traffic would be rejected until the new security group is created
#
# SOLUTION:
# Use a "moved" block to tell Terraform that the resource was renamed,
# not deleted and recreated. This automatically updates the state without touching
# resources in AWS.
# ============================================================================

# This was the old identifier for the security group.
# If we uncomment this and comment out the new resource, we can simulate the initial state.
# resource "aws_security_group" "instance" {
#   name = var.security_group_name
# }

# New identifier after refactoring.
# IMPORTANT: Without the "moved" block below, Terraform would try to delete the old
# resource and create a new one, causing downtime.
resource "aws_security_group" "cluster_instance" {
  name = var.security_group_name
}

# ============================================================================
# MOVED BLOCK: Automatic State Refactoring
# ============================================================================
# The "moved" block tells Terraform that the resource was renamed, not deleted.
# 
# When you run "terraform plan" after adding this block, you'll see:
#   # aws_security_group.instance has moved to
#   # aws_security_group.cluster_instance
#   Plan: 0 to add, 0 to change, 0 to destroy.
#
# This means Terraform will only update the state file, without making changes
# in AWS. The existing security group will remain intact.
#
# ADVANTAGES over "terraform state mv":
#   - Automatic: No need to run manual commands
#   - Documented: The change is recorded in code
#   - Versioned: Can be tracked in Git
#   - Safe: Terraform validates that the move is correct
#
# REQUIREMENT: Terraform >= 1.1
# ============================================================================
moved {
  from = aws_security_group.instance
  to   = aws_security_group.cluster_instance
}
