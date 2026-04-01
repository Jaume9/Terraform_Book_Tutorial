# ============================================================================
# VARIABLE: security_group_name
# ============================================================================
# Name of the Security Group in AWS.
#
# IMPORTANT ABOUT REFACTORING:
#   - If you change the value of this variable after initial deployment,
#     Terraform will try to delete the old security group and create a new one
#   - This will cause downtime because instances will lose their security rules
#   - The "name" parameter in aws_security_group is immutable in AWS
#
# BEST PRACTICES:
#   - Define the correct name from the start
#   - If you need to change the name, consider creating a new security group
#     and migrating instances gradually
#   - Always run "terraform plan" before changing this variable
# ============================================================================
variable "security_group_name" {
  description = "The name to use for the Security Group"
  type        = string
  default     = "moved-example-security-group"
}