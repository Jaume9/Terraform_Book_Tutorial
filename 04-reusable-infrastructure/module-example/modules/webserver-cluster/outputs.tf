# ============================================================================
# OUTPUTS DEL MODULO: valores que el modulo devuelve al llamador
# ============================================================================
# Se acceden desde fuera con: module.<nombre_modulo>.<nombre_output>
# Ejemplo: module.webserver_stage.asg_name

# Nombre del Auto Scaling Group creado
output "asg_name" {
  description = "Nombre del Auto Scaling Group"
  value       = aws_autoscaling_group.example.name
}

# ID del security group (util para conectar un ALB en el futuro)
output "security_group_id" {
  description = "ID del security group de las instancias"
  value       = aws_security_group.instance.id
}

# Puerto en el que escuchan las instancias (por si el llamador lo necesita)
output "server_port" {
  description = "Puerto del servidor web"
  value       = var.server_port
}
