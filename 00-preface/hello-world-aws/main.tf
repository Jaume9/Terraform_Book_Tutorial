# ─── PROVIDER ──────────────────────────────────────────────
# Las credenciales NO van aquí. Se leen automáticamente de:
#   - aws configure  (AWS CLI)
#   - Variables de entorno AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY

provider "aws" {
  region = "eu-west-1"
}

# ─── INSTANCIA EC2  ──────────────────────────────────────────────
resource "aws_instance" "example" {
    ami = "ami-0fb653ca2d3203ac1"
    instance_type = "t3.micro"

      tags = {
    Name = "hello-world"
  }
}