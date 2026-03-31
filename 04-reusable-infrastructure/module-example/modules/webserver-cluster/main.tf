# ============================================================================
# MODULO: webserver-cluster
# ============================================================================
# Este modulo crea un cluster de servidores web con:
#   - Launch template: plantilla de la VM (imagen, tipo, script de arranque)
#   - Auto Scaling Group: mantiene N instancias corriendo siempre
#   - Security Group: abre el puerto del servidor solo desde internet
#
# Se llama desde stage/ y prod/ con distintos parametros.
# ============================================================================

# ── LOCALS ──────────────────────────────────────────────────────────────────
# Valores calculados internamente (no accesibles desde fuera del modulo).
# Evitan repetir la misma expresion en varios recursos.

locals {
  # Prefijo comun para nombres de recursos: "webserver-stage", "webserver-prod"
  name_prefix = "webserver-${var.environment}"

  # Script que se ejecuta al arrancar cada instancia EC2.
  # Levanta un servidor HTTP minimo en el puerto configurado.
  user_data = <<-EOF
    #!/bin/bash
    echo "Hola desde ${var.environment}!" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
  EOF
}

# ── DATA SOURCES ─────────────────────────────────────────────────────────────
# Lee la VPC y subnets por defecto que ya existen en la cuenta de AWS.
# No las crea, solo las consulta para poder referenciarlas.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ── SECURITY GROUP ────────────────────────────────────────────────────────────
# Cortafuegos de las instancias EC2.
# Solo permite trafico entrante en el puerto del servidor web.

resource "aws_security_group" "instance" {
  name        = var.instance_security_group_name
  description = "Permite trafico HTTP al servidor web (${var.environment})"
  vpc_id      = data.aws_vpc.default.id

  # Trafico entrante: acepta peticiones HTTP en el puerto del servidor
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Trafico saliente: permite todo (para descargar paquetes, responder, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-sg"
    Environment = var.environment
  }
}

# ── LAUNCH TEMPLATE ───────────────────────────────────────────────────────────
# Plantilla que define como sera cada instancia EC2 que cree el ASG.
# El ASG usa esta plantilla para lanzar nuevas instancias.

resource "aws_launch_template" "example" {
  name_prefix   = "${local.name_prefix}-"
  image_id      = "ami-0fb653ca2d3203ac1"   # Ubuntu 22.04 en us-east-2
  instance_type = var.instance_type          # t3.micro en stage, t3.small en prod

  # Script de arranque: se ejecuta una vez cuando la instancia arranca
  user_data = base64encode(local.user_data)

  # Asocia el security group a las instancias que cree el ASG
  vpc_security_group_ids = [aws_security_group.instance.id]

  # Necesario para que el ASG pueda reemplazar instancias sin downtime:
  # crea la nueva version del template ANTES de borrar la antigua
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = local.name_prefix
    Environment = var.environment
  }
}

# ── AUTO SCALING GROUP ────────────────────────────────────────────────────────
# Mantiene siempre entre min_size y max_size instancias corriendo.
# Si una instancia falla, el ASG arranca otra automaticamente.

resource "aws_autoscaling_group" "example" {
  name = "${local.name_prefix}-asg"

  # Usa la launch template definida arriba
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  # Despliega las instancias en todas las subnets de la VPC por defecto
  # (una subnet por zona de disponibilidad = alta disponibilidad)
  vpc_zone_identifier = data.aws_subnets.default.ids

  # Limites del cluster: entre min y max instancias siempre activas
  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = local.name_prefix
    propagate_at_launch = true   # este tag se copia a cada instancia creada
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}
