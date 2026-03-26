# ============================================================================
# CONFIGURACION DEL LOAD BALANCER DE APLICACION (ALB) EN AWS
# ============================================================================
# Este ejemplo muestra como crear un ALB (Application Load Balancer) que se
# coloca delante de un Auto Scaling Group (ASG) para repartir el trafico
# entrante entre varias instancias EC2.
#
# Flujo del trafico:
#   Usuario -> ALB (puerto 80) -> Target Group -> Instancias EC2 (puerto 8080)

# Bloque terraform: define la version minima de Terraform y los proveedores necesarios
terraform {
  # Solo acepta versiones 1.x.x, no la 2.0 ni superiores
  required_version = ">= 1.0.0, < 2.0.0"

  # Proveedor de AWS: descargado automaticamente con 'terraform init'
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Bloque provider: indica a Terraform en que region de AWS desplegar los recursos
provider "aws" {
  region = var.aws_region
}

# ============================================================================
# DATA SOURCES: Leer infraestructura ya existente en AWS (sin crearla)
# ============================================================================
# Los data sources consultan recursos que ya existen en la cuenta de AWS.
# No crean nada nuevo, solo leen informacion para usarla en otros recursos.

# Lee la VPC por defecto que AWS crea automaticamente en cada cuenta/region.
# Una VPC es la red privada virtual donde viven las instancias EC2.
data "aws_vpc" "default" {
  default = true
}

# Lee todas las subnets (subredes) dentro de la VPC por defecto.
# El ALB necesita subnets en al menos 2 zonas de disponibilidad distintas
# para garantizar alta disponibilidad (si una zona falla, la otra sigue activa).
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]   # usa el ID de la VPC leida arriba
  }
}

# ============================================================================
# SECURITY GROUP DEL ALB: cortafuegos del load balancer
# ============================================================================
# Un Security Group actua como un cortafuegos virtual.
# Por defecto, AWS bloquea TODO el trafico entrante y saliente.
# Hay que declarar explicitamente que trafico se permite.

resource "aws_security_group" "alb" {
  name        = var.alb_security_group_name
  description = "Cortafuegos del Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id   # asociado a la VPC por defecto

  # TRAFICO ENTRANTE (ingress): lo que puede llegar al ALB desde internet

  # Permite peticiones HTTP en el puerto 80 desde cualquier IP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # 0.0.0.0/0 = cualquier IP del mundo
  }

  # Permite peticiones HTTPS en el puerto 443 desde cualquier IP
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # TRAFICO SALIENTE (egress): lo que puede enviar el ALB hacia fuera

  # Permite todo el trafico saliente (necesario para health checks y reenvio)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"            # -1 = cualquier protocolo
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.alb_security_group_name
  }
}

# ============================================================================
# ALB: el propio Load Balancer
# ============================================================================
# El ALB es el punto de entrada del trafico web. AWS lo gestiona por nosotros:
# corre en varias subnets/zonas de disponibilidad a la vez, escala
# automaticamente y maneja el failover. Nosotros solo declaramos la config.

resource "aws_lb" "example" {
  name = var.alb_name

  # Tipo "application" = capa 7 (HTTP/HTTPS), el mas adecuado para webs.
  # Alternativas: "network" (capa 4, TCP/UDP) o "gateway" (appliances de red)
  load_balancer_type = "application"

  # El ALB se despliega en todas las subnets de la VPC por defecto,
  # lo que garantiza que cubre varias zonas de disponibilidad (multi-AZ).
  subnets = data.aws_subnets.default.ids

  # Asocia el security group definido arriba para controlar el trafico
  security_groups = [aws_security_group.alb.id]

  # false = se puede borrar con 'terraform destroy' (util en tutoriales)
  # En produccion se pondria true para evitar borrados accidentales
  enable_deletion_protection = false

  tags = {
    Name = var.alb_name
  }
}

# ============================================================================
# LISTENER: el "oido" del ALB
# ============================================================================
# Un Listener define en que puerto y protocolo escucha el ALB.
# Cuando llega una peticion, el listener la evalua contra sus reglas (rules)
# para decidir a donde reenviarla.

resource "aws_lb_listener" "http" {
  # A que ALB pertenece este listener
  load_balancer_arn = aws_lb.example.arn

  # Escucha en el puerto 80 (HTTP estandar)
  port = 80

  # Protocolo HTTP (no cifrado). Para HTTPS habria que añadir un certificado SSL.
  protocol = "HTTP"

  # Accion por defecto: si ninguna regla coincide, devuelve un 404.
  # Esto actua como fallback de seguridad.
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
  }
}

# ============================================================================
# TARGET GROUP: el grupo de destino del trafico
# ============================================================================
# Un Target Group es la lista de servidores (instancias EC2) a los que el ALB
# puede enviar trafico. El ALB comprueba periodicamente si cada instancia
# esta sana (health check) antes de enviarle peticiones.

resource "aws_lb_target_group" "asg" {
  name = var.target_group_name

  # Puerto en el que escuchan las instancias EC2 (8080 en este ejemplo)
  port = var.server_port

  protocol = "HTTP"

  # VPC donde estan las instancias que recibiran el trafico
  vpc_id = data.aws_vpc.default.id

  # HEALTH CHECK: el ALB comprueba periodicamente si las instancias estan vivas.
  # Solo envia trafico a las instancias que pasan el health check.
  health_check {
    # Ruta HTTP que se consulta para verificar salud (GET /)
    path = "/"

    protocol = "HTTP"

    # La instancia se considera sana si responde con HTTP 200
    matcher = "200"

    # Frecuencia del chequeo: cada 15 segundos
    interval = 15

    # Tiempo maximo de espera de respuesta: 3 segundos
    timeout = 3

    # Necesita 2 chequeos OK consecutivos para marcar la instancia como sana
    healthy_threshold = 2

    # Necesita 2 chequeos fallidos consecutivos para marcarla como no sana
    unhealthy_threshold = 2
  }

  tags = {
    Name = var.target_group_name
  }
}

# ============================================================================
# LISTENER RULE: regla de enrutamiento del listener
# ============================================================================
# Una Listener Rule define CUANDO y ADONDE reenviar el trafico.
# El listener puede tener multiples reglas con distintas condiciones
# (por URL, por header, etc). Se evaluan por orden de prioridad.
# La accion por defecto del listener (404) solo aplica si ninguna regla coincide.

resource "aws_lb_listener_rule" "asg" {
  # A que listener pertenece esta regla
  listener_arn = aws_lb_listener.http.arn

  # Prioridad: los numeros mas bajos se evaluan primero.
  # Rango valido: 1-50000.
  priority = 100

  # CONDICION: cuando aplica esta regla.
  # "*" = cualquier ruta URL -> esta regla captura todo el trafico.
  condition {
    path_pattern {
      values = ["*"]
    }
  }

  # ACCION: que hacer cuando la condicion se cumple.
  # "forward" = reenviar la peticion al target group (instancias EC2).
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# ============================================================================
# SECURITY GROUP DE LAS INSTANCIAS EC2
# ============================================================================
# Este security group protege las instancias EC2 que estan detras del ALB.
# Principio de menor privilegio: las instancias NO deben ser accesibles
# directamente desde internet; solo deben aceptar trafico proveniente del ALB.

resource "aws_security_group" "instance" {
  name        = var.instance_security_group_name
  description = "Cortafuegos para instancias EC2 detras del ALB"
  vpc_id      = data.aws_vpc.default.id

  # TRAFICO ENTRANTE: solo acepta conexiones desde el security group del ALB.
  # asi las instancias son inaccesibles desde internet directamente.
  ingress {
    from_port       = var.server_port          # puerto 8080
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # solo desde el ALB
  }

  # TRAFICO SALIENTE: permite todo (para descargar paquetes, responder al ALB, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.instance_security_group_name
  }
}