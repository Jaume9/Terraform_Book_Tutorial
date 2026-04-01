# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

# ============================================================================
# VARIABLE: cluster_name
# ============================================================================
# ⚠️ REFACTORING DANGER ⚠️
#
# This variable is used in multiple critical resources:
#   - aws_lb.example.name (line 122)
#   - aws_lb_target_group.asg.name (line 146)
#   - aws_security_group.instance.name (line 97)
#   - aws_security_group.alb.name (line 179)
#   - aws_autoscaling_group.example.name (line 33)
#   - aws_cloudwatch_metric_alarm.*.alarm_name (lines 213, 232)
#
# If you change the value of this variable after resources already exist:
#   - Terraform will try to delete old resources and create new ones
#   - This will cause DOWNTIME because:
#     * The ALB will be deleted → No traffic routing
#     * Security Groups will be deleted → Servers reject traffic
#     * The Target Group will be deleted → No connection to instances
#
# DANGEROUS EXAMPLE:
#   # Before: cluster_name = "foo"
#   # After: cluster_name = "bar"
#   # Result: Terraform deletes all "foo" resources and creates "bar"
#
# SOLUTION:
#   - If you need to change the name, consider creating a new cluster first
#   - Or use "terraform state mv" to move individual resources
#   - Or use "moved" blocks for renamed resources
#   - ALWAYS run "terraform plan" before applying changes
# ============================================================================
variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type        = string
}

variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket for the database's remote state"
  type        = string
}

variable "db_remote_state_key" {
  description = "The path for the database's remote state in S3"
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}

variable "min_size" {
  description = "The minimum number of EC2 Instances in the ASG"
  type        = number
}

variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}

variable "enable_autoscaling" {
  description = "If set to true, enable auto scaling"
  type        = bool
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "ami" {
  description = "The AMI to run in the cluster"
  type        = string
  default     = "ami-0fb653ca2d3203ac1"
}

variable "server_text" {
  description = "The text the web server should return"
  type        = string
  default     = "Hello, World"
}

variable "custom_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}
