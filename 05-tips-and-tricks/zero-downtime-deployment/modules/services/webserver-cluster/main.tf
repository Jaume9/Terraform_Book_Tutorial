terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_launch_configuration" "example" {
  image_id        = var.ami
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance.id]

  user_data       = templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
    server_text = var.server_text
  })

  # ========================================================================
  # LIFECYCLE: create_before_destroy
  # ========================================================================
  # This configuration is CRITICAL to avoid downtime during updates.
  #
  # Without create_before_destroy:
  #   1. Terraform deletes the old launch configuration
  #   2. The Auto Scaling Group is left without valid configuration
  #   3. New instances cannot be created
  #   4. If existing instances fail, there's no replacement
  #   → Potential DOWNTIME
  #
  # With create_before_destroy:
  #   1. Terraform creates the new launch configuration first
  #   2. The Auto Scaling Group can continue working with the old one
  #   3. Once the new one is created, Terraform deletes the old one
  #   → No downtime
  #
  # IMPORTANT: Always use this in critical resources that are referenced
  # by other resources that cannot function without them.
  # ========================================================================
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  # Explicitly depend on the launch configuration's name so each time it's
  # replaced, this ASG is also replaced
  name = "${var.cluster_name}-${aws_launch_configuration.example.name}"

  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  target_group_arns    = [aws_lb_target_group.asg.arn]
  health_check_type    = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  # Wait for at least this many instances to pass health checks before
  # considering the ASG deployment complete
  min_elb_capacity = var.min_size

  # ========================================================================
  # LIFECYCLE: create_before_destroy for Auto Scaling Group
  # ========================================================================
  # Zero-downtime deployment strategy for the ASG.
  #
  # Flow without create_before_destroy (DANGEROUS):
  #   1. Terraform deletes the old ASG
  #   2. All instances are terminated
  #   3. Service is completely offline
  #   4. Terraform creates the new ASG
  #   5. New instances take time to start
  #   → SIGNIFICANT DOWNTIME
  #
  # Flow with create_before_destroy (SAFE):
  #   1. Terraform creates the new ASG first
  #   2. New instances start gradually
  #   3. ALB routes traffic to both versions temporarily
  #   4. Once new instances are healthy, old ASG is deleted
  #   → ZERO DOWNTIME
  #
  # Combined with min_elb_capacity (line 65), this ensures there are always
  # enough healthy instances before deleting the old ones.
  # ========================================================================
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = {
      for key, value in var.custom_tags:
      key => upper(value)
      if key != "Name"
    }

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-scale-out-during-business-hours"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 10
  recurrence             = "0 9 * * *"
  autoscaling_group_name = aws_autoscaling_group.example.name
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-scale-in-at-night"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 2
  recurrence             = "0 17 * * *"
  autoscaling_group_name = aws_autoscaling_group.example.name
}

# ============================================================================
# SECURITY GROUP: Cluster Instances
# ============================================================================
# ⚠️ REFACTORING DANGER ⚠️
#
# If you rename the identifier of this resource (e.g., from "instance" to 
# "cluster_instance"), Terraform will interpret this as deleting the old security group
# and creating a new one.
#
# CONSEQUENCES:
#   - EC2 instances will lose their security rules
#   - Network traffic will be rejected until the new security group is created
#   - Possible service downtime
#
# REFERENCED IN:
#   - aws_launch_configuration.example.security_groups (line 15)
#   - aws_security_group_rule.allow_server_http_inbound.security_group_id (line 170)
#
# IF YOU NEED TO RENAME THIS RESOURCE:
#   1. Add a "moved" block to automatically update the state:
#      moved {
#        from = aws_security_group.instance
#        to   = aws_security_group.cluster_instance
#      }
#   2. Or use: terraform state mv aws_security_group.instance aws_security_group.cluster_instance
#   3. ALWAYS run "terraform plan" first to verify
# ============================================================================
resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"
}

resource "aws_security_group_rule" "allow_server_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instance.id

  from_port   = var.server_port
  to_port     = var.server_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ============================================================================
# APPLICATION LOAD BALANCER (ALB)
# ============================================================================
# ⚠️ CRITICAL RESOURCE - DOWNTIME DANGER ⚠️
#
# This is one of the most critical resources in the cluster. If deleted, all
# traffic to the cluster will be interrupted.
#
# REFACTORING DANGERS:
#   1. Changing var.cluster_name:
#      - If you change the value of cluster_name after deployment, Terraform
#        will try to delete the old ALB and create a new one
#      - This will cause DOWNTIME because there will be nothing to route traffic
#      - The new ALB needs time to initialize
#
#   2. Renaming the "example" identifier:
#      - If you change "aws_lb.example" to "aws_lb.cluster", Terraform will interpret
#        this as deleting the old ALB and creating a new one
#      - Use a "moved" block to avoid this
#
#   3. Changing immutable parameters:
#      - The "name" parameter is immutable in AWS
#      - Any change requires deleting and recreating the resource
#
# REFERENCED IN:
#   - aws_lb_listener.http.load_balancer_arn (line 231)
#   - aws_lb_listener_rule.asg.listener_arn (line 277)
#
# BEST PRACTICES:
#   - Never change the name after initial deployment
#   - If you need to change, consider creating a new ALB first
#   - Always use "terraform plan" before applying changes
#   - Consider using "create_before_destroy" if you really need to replace it
# ============================================================================
resource "aws_lb" "example" {
  name               = var.cluster_name
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.http_port
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# ============================================================================
# TARGET GROUP for Auto Scaling Group
# ============================================================================
# ⚠️ CRITICAL RESOURCE - DOWNTIME DANGER ⚠️
#
# This target group connects the ALB with EC2 instances in the Auto Scaling Group.
# If deleted, the ALB will not be able to route traffic to instances.
#
# REFACTORING DANGERS:
#   - Changing var.cluster_name will cause Terraform to delete and recreate this resource
#   - The "name" parameter is immutable, any change requires recreation
#   - During recreation, the ALB will lose its targets and cannot route traffic
#
# REFERENCED IN:
#   - aws_autoscaling_group.example.target_group_arns (line 37)
#   - aws_lb_listener_rule.asg.action.target_group_arn (line 288)
#
# BEST PRACTICES:
#   - Don't change the name after initial deployment
#   - If you need to change, create the new target group first
#   - Use "terraform plan" to verify impacts before applying
# ============================================================================
resource "aws_lb_target_group" "asg" {
  name     = var.cluster_name
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# ============================================================================
# SECURITY GROUP: Application Load Balancer
# ============================================================================
# ⚠️ REFACTORING DANGER ⚠️
#
# Security group for the ALB. If deleted, the ALB will lose its security rules
# and will not be able to receive HTTP traffic.
#
# DANGERS:
#   - Changing var.cluster_name will cause recreation of the security group
#   - Renaming the "alb" identifier requires using a "moved" block
#   - During recreation, the ALB will lose its security rules
#
# REFERENCED IN:
#   - aws_lb.example.security_groups (line 227)
#   - aws_security_group_rule.allow_http_inbound.security_group_id (line 310)
#   - aws_security_group_rule.allow_all_outbound.security_group_id (line 320)
#
# BEST PRACTICES:
#   - Use "moved" blocks if renaming the identifier
#   - Always verify with "terraform plan" before applying
# ============================================================================
resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-2"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  alarm_name  = "${var.cluster_name}-high-cpu-utilization"
  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Average"
  threshold           = 90
  unit                = "Percent"
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_credit_balance" {
  count = format("%.1s", var.instance_type) == "t" ? 1 : 0

  alarm_name  = "${var.cluster_name}-low-cpu-credit-balance"
  namespace   = "AWS/EC2"
  metric_name = "CPUCreditBalance"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }

  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Minimum"
  threshold           = 10
  unit                = "Count"
}

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}