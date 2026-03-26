# ============================================================================
# VARIABLES: parametros configurables del despliegue
# ============================================================================
# Las variables permiten reutilizar el codigo sin tocarlo.
# Sus valores se pueden sobreescribir en terraform.tfvars o con -var en CLI.

# Region de AWS donde se crean todos los recursos
variable "aws_region" {
  description = "Region de AWS donde se desplegaran los recursos"
  type        = string
  default     = "us-east-2"   # Ohio; es-east-1 es Virginia (la mas usada)
}

# Nombre del ALB. AWS lo usa como identificador visible en la consola.
variable "alb_name" {
  description = "Nombre del Application Load Balancer"
  type        = string
  default     = "terraform-asg-example"

  # Bloque validation: Terraform comprueba esta condicion antes de crear recursos.
  # Si falla, muestra el error_message y detiene el apply.
  validation {
    condition     = length(var.alb_name) <= 32
    error_message = "El nombre del ALB no puede superar 32 caracteres (limite de AWS)."
  }
}

# Nombre del security group del ALB
variable "alb_security_group_name" {
  description = "Nombre del security group para el ALB"
  type        = string
  default     = "terraform-example-alb"
}

# Nombre del security group de las instancias EC2
variable "instance_security_group_name" {
  description = "Nombre del security group para las instancias EC2"
  type        = string
  default     = "terraform-example-instance"
}

# Nombre del Target Group. Mismo limite de 32 caracteres que el ALB.
variable "target_group_name" {
  description = "Nombre del Target Group del ALB"
  type        = string
  default     = "terraform-asg-example"

  validation {
    condition     = length(var.target_group_name) <= 32
    error_message = "El nombre del Target Group no puede superar 32 caracteres."
  }
}

# Puerto en el que escucha el servidor web dentro de las instancias EC2.
# Los puertos 0-1023 estan reservados al sistema, por eso la validacion exige > 1024.
variable "server_port" {
  description = "Puerto del servidor web en las instancias EC2"
  type        = number
  default     = 8080

  validation {
    condition     = var.server_port > 1024 && var.server_port < 65536
    error_message = "El puerto debe estar entre 1025 y 65535."
  }
}