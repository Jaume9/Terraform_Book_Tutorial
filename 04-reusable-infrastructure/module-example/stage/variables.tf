# Variables de configuracion para el entorno de staging

variable "aws_region" {
  description = "Region de AWS"
  type        = string
  default     = "us-east-2"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"   # el mas barato: ~$0.01/hora
}

variable "server_port" {
  description = "Puerto del servidor web"
  type        = number
  default     = 8080
}

variable "instance_security_group_name" {
  description = "Nombre del security group de las instancias"
  type        = string
  default     = "webserver-stage-sg"
}

variable "min_size" {
  description = "Minimo de instancias en el ASG"
  type        = number
  default     = 1   # stage: minimo 1 para ahorrar coste
}

variable "max_size" {
  description = "Maximo de instancias en el ASG"
  type        = number
  default     = 2
}
