# ============================================================================
# TERRAFORM.TFVARS: valores concretos de las variables
# ============================================================================
# Este fichero asigna valores a las variables definidas en variables.tf.
# Terraform lo carga automaticamente si se llama 'terraform.tfvars'.
# Los valores aqui sobreescriben los 'default' de variables.tf.
# NO subir a git si contiene secretos (passwords, API keys, etc.).

# Region de AWS donde se desplegaran todos los recursos
aws_region = "us-east-2"

# Nombre visible del Load Balancer en la consola de AWS
alb_name = "terraform-asg-example"

# Nombre del cortafuegos (security group) del Load Balancer
alb_security_group_name = "terraform-example-alb"

# Nombre del cortafuegos (security group) de las instancias EC2
instance_security_group_name = "terraform-example-instance"

# Nombre del grupo de destino al que el ALB envia el trafico
target_group_name = "terraform-asg-example"

# Server port
server_port = 8080