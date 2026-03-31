# ============================================================================
# STAGE: entorno de pruebas (pre-produccion)
# ============================================================================
# Llama al modulo webserver-cluster con configuracion barata:
#   - instancias t3.micro (las mas baratas)
#   - solo 1 instancia minima (ahorra coste)
#   - max 2 instancias si sube la carga
#
# Flujo:
#   cd stage/
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
# Aqui es donde la magia ocurre: con 3 lineas de parametros obtienes
# todo el cluster (security group + launch template + ASG).

module "webserver_stage" {
  # Ruta relativa al modulo desde esta carpeta
  source = "../modules/webserver-cluster"

  # Inputs del modulo: configuracion especifica de staging
  environment                  = "stage"
  instance_type                = var.instance_type          # t3.micro
  server_port                  = var.server_port            # 8080
  instance_security_group_name = var.instance_security_group_name
  min_size                     = var.min_size               # 1
  max_size                     = var.max_size               # 2
}
