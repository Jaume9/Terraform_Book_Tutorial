# ============================================================================
# PROD: entorno de produccion
# ============================================================================
# Llama al MISMO modulo que stage pero con configuracion mas potente:
#   - instancias t3.small (mas potentes que t3.micro)
#   - minimo 2 instancias (alta disponibilidad: si una cae, la otra aguanta)
#   - max 10 instancias para absorber picos de trafico
#
# IMPORTANTE: desplegar en carpetas separadas = imposible borrar prod
# por accidente mientras trabajas en stage.
#
# Flujo:
#   cd prod/
#   terraform init
#   terraform apply
#   terraform destroy   (cuando termines, para no pagar)
# ============================================================================

terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── LLAMADA AL MODULO ─────────────────────────────────────────────────────────
# El mismo modulo que stage, pero con parametros de produccion.
# El codigo del modulo no cambia: solo cambian los valores que le pasamos.

module "webserver_prod" {
  # La ruta es identica: apunta al mismo modulo
  source = "../modules/webserver-cluster"

  # Inputs del modulo: configuracion especifica de produccion
  environment                  = "prod"
  instance_type                = var.instance_type          # t3.small
  server_port                  = var.server_port            # 8080
  instance_security_group_name = var.instance_security_group_name
  min_size                     = var.min_size               # 2 (alta disponibilidad)
  max_size                     = var.max_size               # 10
}
