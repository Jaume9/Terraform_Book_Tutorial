# Variables de configuracion para el entorno de produccion

variable "aws_region" {
  description = "Region de AWS"
  type        = string
  default     = "us-east-2"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.small"   # mas potente que stage: ~$0.02/hora
}

variable "server_port" {
  description = "Puerto del servidor web"
  type        = number
  default     = 8080
}

variable "instance_security_group_name" {
  description = "Nombre del security group de las instancias"
  type        = string
  default     = "webserver-prod-sg"
}

variable "min_size" {
  description = "Minimo de instancias en el ASG"
  type        = number
  default     = 2   # prod: minimo 2 para alta disponibilidad
}

variable "max_size" {
  description = "Maximo de instancias en el ASG"
  type        = number
  default     = 10  # prod: puede escalar hasta 10 en picos de trafico
}
