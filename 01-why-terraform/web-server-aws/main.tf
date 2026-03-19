# Configure Terraform version and AWS provider requirements
terraform {
  # Enforce Terraform version between 1.0.0 and 2.0.0
  required_version = ">= 1.0.0, < 2.0.0"

  # Define required provider versions and sources
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS provider with the specified region
resource "aws_instance" "app" {
    instance_type = "t2.micro"
    availability_zone = "us-east-2a"
    ami = "ami-0fb653ca2d3203ac1"

    # Use user_data to run a script that starts the Apache web server on the instance
    user_data = <<-EOF
                #!/bin/bash
                sudo service apache2 start
                EOF
}