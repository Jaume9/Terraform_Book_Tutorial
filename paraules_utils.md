# Glosario: palabras que escucho en las dailys

Palabras que no entendia en las reuniones de daily's y en el libro.

---

## Infraestructura general

| Termino | Explicacion rapida |
|---------|-------------------|
| **On-prem** (on premises) | Servidores fisicos que estan en las oficinas de la empresa, no en la nube. Lo contrario de cloud. |
| **Core prod** | El nucleo del sistema en produccion, es decir, la parte mas critica que los usuarios reales estan usando ahora mismo. Tocar core prod sin cuidado puede tirar el servicio. |
| **Cluster de servidores web** | Un grupo de varias maquinas que hacen lo mismo. Si una falla, las otras siguen respondiendo. Da alta disponibilidad. |
| **Cluster de Kubernetes** (k8s) | Un grupo de maquinas gestionadas por Kubernetes, que se encarga de arrancar, parar y escalar contenedores automaticamente. |
| **Dispatcher** | Componente que recibe tareas o peticiones y las reparte entre los trabajadores disponibles. Como el maitre de un restaurante. |

---

## Redes

| Termino | Explicacion rapida |
|---------|-------------------|
| **VPC** (Virtual Private Cloud) | Red privada virtual en AWS. Es el "edificio" dentro del cual viven tus servidores, aislado del resto de internet. |
| **VNet** (Virtual Network) | Lo mismo que VPC pero en Azure. Una red privada virtual donde viven las maquinas de Azure. |
| **Spoke** | En arquitecturas hub-and-spoke, el spoke es una red secundaria que se conecta a una red central (hub). El hub suele tener los servicios compartidos (seguridad, DNS) y los spokes son los entornos (stage, prod, etc.). |
| **Express Route** | Conexion de red privada y dedicada entre las oficinas de la empresa (on-prem) y Azure. Mas rapido y seguro que ir por internet normal. Es el equivalente de Azure a AWS Direct Connect. |

---

## Trafico y balanceo

| Termino | Explicacion rapida |
|---------|-------------------|
| **Load Balancer** | Repartidor de trafico. Recibe las peticiones de los usuarios y las distribuye entre varios servidores para que ninguno se sature. |
| **ALB** (Application Load Balancer) | Tipo de load balancer de AWS para trafico HTTP/HTTPS. Puede enrutar segun la URL o las cabeceras. |
| **ASG** (Auto Scaling Group) | Grupo de instancias EC2 en AWS que se escala automaticamente: si sube el trafico, arranca mas maquinas; si baja, las apaga para ahorrar coste. |

---

## Terraform

| Termino | Explicacion rapida |
|---------|-------------------|
| **State** | Fichero donde Terraform guarda el estado actual de la infraestructura. Lo usa para saber que cambios hay que hacer al ejecutar `terraform plan`. |
| **Workspace** | En Terraform, permite tener multiples copias del state (dev, staging, prod) usando el mismo codigo. |
| **Module** | Carpeta de Terraform reutilizable. Como una funcion: la defines una vez y la llamas con distintos parametros para crear la misma infraestructura en distintos entornos. |
| **Argumentos** | Los parametros que se pasan a un modulo o recurso de Terraform. Equivalen a los argumentos de una funcion en programacion. |

---

## Aplicacion y negocio

| Termino | Explicacion rapida |
|---------|-------------------|
| **Micropolizas** | Polizas de seguro divididas en partes pequenas gestionadas por microservicios independientes. Cada microservicio se encarga de un tipo de poliza o de una operacion concreta. |
| **Spec routes** | Rutas definidas en una especificacion de API (normalmente OpenAPI/Swagger). Son los endpoints HTTP que la aplicacion expone, documentados formalmente. |


apt in
