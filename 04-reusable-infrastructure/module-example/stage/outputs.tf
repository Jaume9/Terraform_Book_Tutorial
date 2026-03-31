# Outputs de staging: acceden a los outputs del modulo con module.<nombre>.<output>

output "asg_name" {
  description = "Nombre del Auto Scaling Group de staging"
  value       = module.webserver_stage.asg_name
}

output "security_group_id" {
  description = "ID del security group de staging"
  value       = module.webserver_stage.security_group_id
}

output "server_port" {
  description = "Puerto del servidor web de staging"
  value       = module.webserver_stage.server_port
}
