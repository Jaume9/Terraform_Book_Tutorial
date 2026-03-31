# Terraform Tips & Tricks

## 1. Loops

Terraform tiene 4 formas de hacer loops, cada una para un caso distinto.

---

### `count` — Loop simple sobre recursos

Crea N copias de un recurso usando un número entero.

```hcl
resource "aws_iam_user" "example" {
  count = 3
  name  = "user-${count.index}"
}
```

- `count.index` da el índice (0, 1, 2...)
- Para usar nombres personalizados, pasa una lista:

```hcl
variable "user_names" {
  type    = list(string)
  default = ["alice", "bob", "carol"]
}

resource "aws_iam_user" "example" {
  count = length(var.user_names)
  name  = var.user_names[count.index]
}
```

⚠️ **Problema con `count`**: los recursos se identifican por índice. Si borras un elemento del medio de la lista, Terraform recrea todos los recursos posteriores.

---

### `for_each` — Loop sobre maps o sets (recomendado)

Mejor que `count` porque identifica cada recurso por clave, no por índice.

```hcl
variable "user_names" {
  type    = set(string)
  default = ["alice", "bob", "carol"]
}

resource "aws_iam_user" "example" {
  for_each = var.user_names
  name     = each.value
}
```

Con un map podemos pasar más datos:

```hcl
variable "users" {
  type = map(object({
    department = string
    role       = string
  }))
  default = {
    alice = { department = "engineering", role = "admin" }
    bob   = { department = "finance",     role = "viewer" }
  }
}

resource "aws_iam_user" "example" {
  for_each = var.users
  name     = each.key
  tags     = { department = each.value.department }
}
```

- `each.key` — la clave del map
- `each.value` — el valor del map
- Los recursos quedan como `aws_iam_user.example["alice"]`, no por índice

---

### `for` expressions — Transformar listas/maps

No crea recursos, transforma colecciones dentro de expresiones.

```hcl
# Lista → lista transformada
output "upper_names" {
  value = [for name in var.user_names : upper(name)]
}

# Lista → map
output "users_map" {
  value = { for name in var.user_names : name => upper(name) }
}

# Filtrar con if
output "long_names" {
  value = [for name in var.user_names : name if length(name) > 4]
}
```

---

### `dynamic` blocks — Loop dentro de bloques anidados

Cuando el recurso tiene un bloque repetible (como `ingress` en un security group):

```hcl
variable "ingress_rules" {
  type = list(object({
    port        = number
    description = string
  }))
  default = [
    { port = 80,  description = "HTTP"  },
    { port = 443, description = "HTTPS" },
  ]
}

resource "aws_security_group" "example" {
  name = "example"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      description = ingress.value.description
    }
  }
}
```

---

## 2. If-statements y Condicionales

Terraform no tiene `if` como tal, pero hay varios patrones equivalentes.

---

### Expresión ternaria

```hcl
condition ? value_if_true : value_if_false
```

```hcl
variable "enable_ha" {
  type    = bool
  default = false
}

resource "aws_instance" "example" {
  count         = var.enable_ha ? 3 : 1
  instance_type = var.enable_ha ? "t3.large" : "t3.micro"
  ami           = "ami-12345"
}
```

---

### `count = 0` para crear/no crear un recurso

El patrón más común: si la condición es false, `count = 0` → no se crea el recurso.

```hcl
variable "create_dns_record" {
  type    = bool
  default = true
}

resource "aws_route53_record" "example" {
  count = var.create_dns_record ? 1 : 0
  # ...
}
```

Acceder al recurso condicional: usa `one()` para evitar errores si count=0:

```hcl
output "dns_record" {
  value = one(aws_route53_record.example[*].fqdn)
}
```

---

### `for_each` con maps condicionados

```hcl
# Solo crea recursos para los entornos habilitados
variable "environments" {
  type = map(bool)
  default = {
    dev  = true
    prod = false   # no se creará
  }
}

resource "aws_s3_bucket" "example" {
  for_each = { for env, enabled in var.environments : env => enabled if enabled }
  bucket   = "my-bucket-${each.key}"
}
```

---

### Variables con `null` y `try()`

```hcl
# Si la variable es null, usa el valor por defecto
resource "aws_instance" "example" {
  ami           = coalesce(var.custom_ami, data.aws_ami.default.id)
  instance_type = try(var.instance_config.type, "t3.micro")
}
```

- `coalesce(a, b)` — devuelve el primer valor no-null
- `try(expr, fallback)` — si la expresión falla, usa el fallback

---

## 3. Zero-Downtime Deployment

El problema: cuando Terraform actualiza un recurso que requiere reemplazo (destroy + create), hay downtime. Hay varios patrones para evitarlo.

---

### `create_before_destroy`

Por defecto Terraform destruye primero y luego crea. Con este lifecycle lo invierte:

```hcl
resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }
}
```

⚠️ Cuidado: si el recurso nuevo tiene el mismo nombre único que el viejo, fallará. Hay que usar nombres generados (con `random_id` o sufijos).

---

### Rolling deployment con ASG (AWS) / VMSS (Azure)

El patrón estándar en producción: el Auto Scaling Group crea instancias nuevas antes de terminar las viejas.

```hcl
resource "aws_autoscaling_group" "example" {
  name             = "${aws_launch_configuration.example.name}-asg"
  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  # Esperar a que las instancias nuevas estén healthy antes de terminar las viejas
  min_elb_capacity = 2

  lifecycle {
    create_before_destroy = true
  }
}

# La launch config tiene el AMI/config de la instancia
resource "aws_launch_configuration" "example" {
  image_id      = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }
}
```

Truco: forzar recreación del ASG cuando cambia la `launch_configuration` incluyendo su nombre en el nombre del ASG.

---

### Blue/Green deployment

Mantener dos entornos idénticos (blue = actual, green = nuevo) y switchear el tráfico:

```hcl
variable "active_color" {
  type    = string
  default = "blue"  # cambiar a "green" para el switch
}

module "blue" {
  source = "../modules/webserver-cluster"
  count  = var.active_color == "blue" ? 1 : 0
}

module "green" {
  source = "../modules/webserver-cluster"
  count  = var.active_color == "green" ? 1 : 0
}

resource "aws_route53_record" "example" {
  name = "api.example.com"
  # apunta al módulo activo
  records = var.active_color == "blue" ? [module.blue[0].ip] : [module.green[0].ip]
}
```

---

### `ignore_changes` para evitar actualizaciones no deseadas

Cuando hay atributos que cambian fuera de Terraform (ej: una imagen de contenedor actualizada por el CI/CD):

```hcl
resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    ignore_changes = [ami]  # Terraform no actualizará la AMI en futuros plans
  }
}
```

---

## Resumen rápido

| Necesidad | Herramienta |
|-----------|-------------|
| Crear N recursos iguales | `count` |
| Crear recursos con nombres únicos | `for_each` |
| Transformar una lista en otra | `for` expression |
| Repetir bloques dentro de un recurso | `dynamic` block |
| Crear/no crear un recurso condicionalmente | `count = var ? 1 : 0` |
| Lógica condicional en valores | expresión ternaria `? :` |
| Evitar downtime en actualizaciones | `create_before_destroy` + ASG rolling |
| No tocar un atributo en futuros plans | `ignore_changes` |
