# ============================================================================
# OUTPUTS: informacion que Terraform muestra al terminar el 'apply'
# ============================================================================
# Los outputs son como el "return" del codigo: exponen valores utiles
# una vez que los recursos han sido creados. Tambien sirven para pasar
# datos entre modulos de Terraform.

# Nombre DNS del ALB: la URL publica para acceder a la aplicacion.
# Ejemplo: terraform-asg-example-123456789.us-east-2.elb.amazonaws.com
output "alb_dns_name" {
  description = "URL publica del Load Balancer (copiar en el navegador para probar)"
  value       = aws_lb.example.dns_name
}

# ARN del ALB: identificador unico de AWS para el recurso.
# Se usa para referenciar el ALB desde otros servicios de AWS.
output "alb_arn" {
  description = "ARN (identificador unico) del Load Balancer en AWS"
  value       = aws_lb.example.arn
}

# ARN del Target Group: util si luego se quiere conectar un ASG a este TG
# desde otro modulo o stack de Terraform.
output "target_group_arn" {
  description = "ARN del Target Group (necesario para conectar el ASG)"
  value       = aws_lb_target_group.asg.arn
}

# Output: ALB security group ID
output "alb_security_group_id" {
  description = "ID of the security group for the ALB"
  value       = aws_security_group.alb.id
}

# Output: Instance security group ID
output "instance_security_group_id" {
  description = "ID of the security group for EC2 instances"
  value       = aws_security_group.instance.id
}