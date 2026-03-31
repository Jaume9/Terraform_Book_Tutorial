# Terraform Tips & Tricks

Terraform no es un lenguaje de programación, pero tiene mecanismos para hacer loops, condicionales y deployments sin downtime. Este capítulo cubre las herramientas principales.

---

## 1. Loops con el parámetro `count`

`count` es el mecanismo más básico de loop: le dice a Terraform cuántas copias de un recurso crear.

### Cómo funciona

Dentro del recurso tienes acceso a `count.index` (el índice actual: 0, 1, 2...).

```hcl
resource "aws_iam_user" "example" {
  count = 3
  name  = "user-${count.index}"
}
# Crea: user-0, user-1, user-2
```

### Con una lista de nombres

```hcl
variable "user_names" {
  description = "Lista de usuarios a crear"
  type        = list(string)
  default     = ["alice", "bob", "carol"]
}

resource "aws_iam_user" "example" {
  count = length(var.user_names)
  name  = var.user_names[count.index]
}
```

### Acceder a los recursos creados

Los recursos con `count` quedan como una lista indexada:

```hcl
output "first_user_arn" {
  value = aws_iam_user.example[0].arn
}

output "all_user_arns" {
  value = aws_iam_user.example[*].arn  # splat expression
}
```

### ⚠️ Problema con `count` y listas

Los recursos se identifican por **índice**, no por valor. Si eliminas `"bob"` de la lista:

```
# Lista original:  ["alice", "bob", "carol"]  → índices 0, 1, 2
# Lista nueva:     ["alice", "carol"]          → índices 0, 1

# Terraform ve esto como:
# user[1] cambia de "bob" → "carol"   (update)
# user[2] = "carol" desaparece        (destroy)
```

Terraform modifica `bob` y destruye `carol` en lugar de simplemente borrar `bob`. Para evitar esto, usar `for_each`.

---

## 2. Loops con expresiones `for_each`

`for_each` itera sobre un **map** o **set**, identificando cada recurso por su clave — no por índice. Esto lo hace más robusto que `count`.

### Con un set de strings

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

Los recursos quedan como `aws_iam_user.example["alice"]`, `aws_iam_user.example["bob"]`, etc. Si borras `"bob"`, solo se destruye ese recurso — los demás no se tocan.

### Con un map de objetos

Permite pasar más datos por cada elemento:

```hcl
variable "users" {
  type = map(object({
    department = string
    is_admin   = bool
  }))
  default = {
    alice = { department = "engineering", is_admin = true  }
    bob   = { department = "finance",     is_admin = false }
  }
}

resource "aws_iam_user" "example" {
  for_each = var.users
  name     = each.key   # "alice", "bob"

  tags = {
    Department = each.value.department
    Admin      = each.value.is_admin
  }
}
```

### Acceder a los recursos creados

Con `for_each` los recursos son un map, no una lista:

```hcl
output "all_user_arns" {
  value = values(aws_iam_user.example)[*].arn
}

output "alice_arn" {
  value = aws_iam_user.example["alice"].arn
}
```

### `for_each` en módulos

También se puede aplicar `for_each` a módulos enteros:

```hcl
module "users" {
  source   = "../modules/iam-user"
  for_each = var.users

  username   = each.key
  department = each.value.department
}
```

---

## 3. Loops con expresiones `for`

Las expresiones `for` no crean recursos — **transforman colecciones** (listas y maps) dentro de expresiones. Son el equivalente de `map()` y `filter()` en otros lenguajes.

### Lista → lista transformada

```hcl
variable "names" {
  default = ["alice", "bob", "carol"]
}

output "upper_names" {
  value = [for name in var.names : upper(name)]
}
# Resultado: ["ALICE", "BOB", "CAROL"]
```

### Lista → map

```hcl
output "names_map" {
  value = { for name in var.names : name => upper(name) }
}
# Resultado: { "alice" = "ALICE", "bob" = "BOB", "carol" = "CAROL" }
```

### Iterar sobre un map

```hcl
variable "hero_thousand_faces" {
  type = map(string)
  default = {
    neo   = "hero"
    trinity = "love interest"
    morpheus = "mentor"
  }
}

output "bios" {
  value = [for name, role in var.hero_thousand_faces : "${name} is the ${role}"]
}
# Resultado: ["morpheus is the mentor", "neo is the hero", "trinity is the love interest"]
```

### Filtrar con `if`

```hcl
output "short_names" {
  value = [for name in var.names : upper(name) if length(name) < 5]
}
# Solo nombres con menos de 5 caracteres, en mayúsculas
```

---

## 4. Loops con string directives

Las **string directives** permiten usar loops y condicionales **dentro de strings multilínea** (heredoc). Usan la sintaxis `%{ }`.

### `%{ for }` — loop dentro de un string

```hcl
variable "names" {
  default = ["alice", "bob", "carol"]
}

output "for_directive" {
  value = <<EOF
%{ for name in var.names }
Hello, ${name}!
%{ endfor }
EOF
}
```

Resultado:
```
Hello, alice!
Hello, bob!
Hello, carol!
```

### Eliminar líneas en blanco extra con `~`

El `~` elimina el whitespace/newline antes o después de la directiva:

```hcl
output "for_directive_strip" {
  value = <<EOF
%{~ for name in var.names ~}
${name}, %{~ endfor ~}
EOF
}
# Resultado: "alice, bob, carol, "
```

### Caso de uso real: generar configuración dinámica

```hcl
resource "local_file" "hosts" {
  content = <<EOF
%{ for ip in var.server_ips ~}
${ip}
%{ endfor ~}
EOF
  filename = "/etc/hosts.txt"
}
```

---

## 5. Condicionales con el parámetro `count`

El patrón más habitual: usar `count = 0` para "no crear" y `count = 1` para "sí crear".

### Crear/no crear un recurso según una variable booleana

```hcl
variable "enable_autoscaling" {
  description = "Habilitar autoscaling"
  type        = bool
}

resource "aws_autoscaling_schedule" "scale_out" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "scale-out-in-the-morning"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 10
  recurrence             = "0 9 * * *"
  autoscaling_group_name = aws_autoscaling_group.example.name
}
```

### Comportamiento diferente según el entorno

```hcl
variable "environment" {
  type = string  # "dev" o "prod"
}

# Solo en prod: crear 3 instancias. En dev: solo 1
resource "aws_instance" "example" {
  count         = var.environment == "prod" ? 3 : 1
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
}
```

### Acceder a un recurso condicional de forma segura

Cuando `count` puede ser 0, usar `one()` para no obtener errores:

```hcl
output "public_ip" {
  value = one(aws_instance.example[*].public_ip)
  # Devuelve null si count=0, o el valor si count=1
}
```

---

## 6. Condicionales con expresiones `for_each` y `for`

### `for_each` condicional: filtrar qué recursos crear

Convertir un map a otro excluyendo entradas con `if`:

```hcl
variable "subscriptions" {
  type = map(object({
    enabled    = bool
    plan_level = string
  }))
  default = {
    alice = { enabled = true,  plan_level = "pro"  }
    bob   = { enabled = false, plan_level = "free" }
    carol = { enabled = true,  plan_level = "free" }
  }
}

# Solo crea recursos para suscripciones habilitadas
resource "aws_iam_user" "active" {
  for_each = {
    for name, sub in var.subscriptions : name => sub
    if sub.enabled
  }
  name = each.key
}
# Resultado: solo crea "alice" y "carol"
```

### `for` condicional: filtrar valores de un output

```hcl
output "pro_users" {
  value = [
    for name, sub in var.subscriptions : name
    if sub.plan_level == "pro"
  ]
}
# Resultado: ["alice"]
```

### Combinar `for_each` con lógica compleja

```hcl
locals {
  # Solo los usuarios admin de entornos habilitados
  admin_users = {
    for name, user in var.users : name => user
    if user.is_admin && user.enabled
  }
}

resource "aws_iam_role_policy_attachment" "admin" {
  for_each   = local.admin_users
  user       = each.key
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
```

---

## 7. Condicionales con el `if` string directive

Igual que el `for` directive pero para condicionales dentro de strings/heredocs.

### `%{ if condition }` básico

```hcl
variable "show_admin_info" {
  type    = bool
  default = true
}

output "message" {
  value = "Hello%{ if var.show_admin_info }, admin%{ endif }!"
}
# Si true:  "Hello, admin!"
# Si false: "Hello!"
```

### Con `else`

```hcl
variable "environment" {
  default = "prod"
}

output "env_message" {
  value = "Environment: %{ if var.environment == "prod" }PRODUCTION%{ else }non-production%{ endif }"
}
```

### Caso de uso real: generar config condicional

```hcl
resource "local_file" "nginx_config" {
  content = <<-EOF
    server {
      listen 80;
      %{ if var.enable_ssl ~}
      listen 443 ssl;
      ssl_certificate /etc/ssl/cert.pem;
      %{ endif ~}
      server_name ${var.domain};
    }
  EOF
  filename = "/etc/nginx/nginx.conf"
}
```

---

## 8. Zero-Downtime Deployment

El problema: cuando Terraform actualiza un recurso que requiere **reemplazo** (destroy + create), hay downtime. Estos patrones lo evitan.

### El problema sin solución

```
Plan: 1 to destroy, 1 to create

# aws_instance.web (destroy first, then create)
# → Los usuarios ven downtime durante el destroy
```

---

### Solución 1: `create_before_destroy`

Invierte el orden por defecto: **primero crea el nuevo recurso, luego destruye el viejo**.

```hcl
resource "aws_launch_configuration" "example" {
  image_id        = var.ami
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello" > index.html
    nohup busybox httpd -f -p 8080 &
  EOF

  lifecycle {
    create_before_destroy = true
  }
}
```

⚠️ **Limitación**: si el recurso nuevo requiere el mismo nombre único que el viejo, fallará con conflicto. Solución: usar nombres generados dinámicamente con `name_prefix` en lugar de `name`.

```hcl
resource "aws_launch_configuration" "example" {
  name_prefix     = "webserver-"   # ← prefijo, AWS genera el nombre único
  image_id        = var.ami
  instance_type   = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }
}
```

---

### Solución 2: Rolling deployment con ASG

El Auto Scaling Group (ASG) crea instancias nuevas y espera a que estén healthy **antes** de terminar las viejas.

```hcl
resource "aws_autoscaling_group" "example" {
  # Nombre ligado al launch config: fuerza recreación cuando cambia la config
  name = "${aws_launch_configuration.example.name}-asg"

  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  # Zero-downtime: esperar hasta que al menos min_elb_capacity instancias
  # estén healthy en el load balancer ANTES de destruir las viejas
  min_elb_capacity = var.min_size

  lifecycle {
    create_before_destroy = true
  }
}
```

**Flujo de zero-downtime con ASG:**
1. Terraform crea el nuevo `launch_configuration` (nueva AMI/config)
2. Terraform crea el nuevo ASG con el nombre del nuevo launch config
3. AWS levanta instancias nuevas con la nueva config
4. El health check espera a que `min_elb_capacity` instancias estén healthy
5. Solo entonces Terraform destruye el ASG viejo
6. AWS termina las instancias viejas
7. En ningún momento hay cero instancias activas → sin downtime

---

### Solución 3: Blue/Green deployment

Mantener **dos entornos** idénticos (blue = actual en prod, green = nuevo) y cambiar el tráfico de golpe.

```hcl
variable "active_env" {
  description = "Entorno activo: blue o green"
  type        = string
  default     = "blue"
}

module "blue" {
  source   = "../modules/webserver-cluster"
  for_each = var.active_env == "blue" ? toset(["active"]) : toset([])
  # config del cluster...
}

module "green" {
  source   = "../modules/webserver-cluster"
  for_each = var.active_env == "green" ? toset(["active"]) : toset([])
  # config del cluster...
}

# El DNS apunta al entorno activo
resource "aws_route53_record" "example" {
  zone_id = data.aws_route53_zone.example.zone_id
  name    = "app.example.com"
  type    = "A"
  records = var.active_env == "blue" ? [module.blue["active"].ip] : [module.green["active"].ip]
  ttl     = 60
}
```

**Flujo Blue/Green:**
1. `active_env = "blue"` → el tráfico va a blue, green no existe
2. Cambias `active_env = "green"` en una PR
3. Terraform crea green, switch del DNS, luego destruye blue
4. Para hacer rollback: basta con volver `active_env = "blue"`

---

### `ignore_changes` — Evitar reemplazos no deseados

Cuando un atributo cambia fuera de Terraform (ej: el CI/CD actualiza la imagen de un contenedor), evita que Terraform fuerce un reemplazo innecesario:

```hcl
resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    ignore_changes = [ami]
    # Terraform ya no intentará actualizar la AMI en futuros plans
  }
}
```

---

## Resumen rápido

| Necesidad | Herramienta |
|-----------|-------------|
| Crear N recursos iguales | `count` |
| Crear recursos identificados por nombre | `for_each` con set/map |
| Crear/no crear un recurso condicionalmente | `count = condition ? 1 : 0` |
| Crear un subconjunto de recursos | `for_each` con `if` en la expresión `for` |
| Transformar una lista o map | expresión `for` |
| Repetir bloques anidados dentro de un recurso | `dynamic` block |
| Loop dentro de un string/heredoc | `%{ for }...%{ endfor }` |
| Condicional dentro de un string/heredoc | `%{ if }...%{ endif }` |
| Evitar downtime en updates simples | `lifecycle { create_before_destroy = true }` |
| Evitar downtime con muchas instancias | ASG rolling + `min_elb_capacity` |
| Switch instantáneo entre versiones | Blue/Green deployment |
| No tocar un atributo en futuros plans | `lifecycle { ignore_changes = [...] }` |

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
