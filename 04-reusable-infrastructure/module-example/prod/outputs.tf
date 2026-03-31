# Outputs de produccion: acceden a los outputs del modulo con module.<nombre>.<output>

output "asg_name" {
  description = "Nombre del Auto Scaling Group de produccion"
  value       = module.webserver_prod.asg_name
}

output "security_group_id" {
  description = "ID del security group de produccion"
  value       = module.webserver_prod.security_group_id
}

output "server_port" {
  description = "Puerto del servidor web de produccion"
  value       = module.webserver_prod.server_port
}
