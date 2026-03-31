# ============================================================================
# INPUTS DEL MODULO: parametros que el llamador debe (o puede) pasar
# ============================================================================

# Nombre del entorno: aparece en los tags y nombres de recursos
variable "environment" {
  description = "Nombre del entorno (stage, prod...)"
  type        = string
}

# Tipo de instancia EC2: controla el coste y la potencia
variable "instance_type" {
  description = "Tipo de instancia EC2 (t3.micro, t3.small...)"
  type        = string
  default     = "t3.micro"   # el mas barato por defecto
}

# Puerto en el que escucha el servidor web dentro de la instancia
variable "server_port" {
  description = "Puerto del servidor web"
  type        = number
  default     = 8080
}

# Nombre del security group de las instancias
variable "instance_security_group_name" {
  description = "Nombre del security group para las instancias EC2"
  type        = string
}

# Minimo de instancias en el Auto Scaling Group
variable "min_size" {
  description = "Numero minimo de instancias en el ASG"
  type        = number
  default     = 1
}

# Maximo de instancias en el Auto Scaling Group
variable "max_size" {
  description = "Numero maximo de instancias en el ASG"
  type        = number
  default     = 2
}
