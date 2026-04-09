# Glosario: palabras que escucho en las dailys

Palabras que no entendia en las reuniones de daily's y en el libro.

---

## Infraestructura general

| Termino | Explicacion rapida |
|---------|-------------------|
| **On-prem** (on premises) | Servidores fisicos que estan en las oficinas de la empresa, no en la nube. Lo contrario de cloud. |
| **Core prod** | El nucleo del sistema en produccion, es decir, la parte mas critica que los usuarios reales estan usando ahora mismo. Tocar core prod sin cuidado puede tirar el servicio. |
| **Cluster de servidores web** | Un grupo de varias maquinas que hacen lo mismo. Si una falla, las otras siguen respondiendo. Da alta disponibilidad. |
| **Kubernetes** (k8s) | Plataforma open-source de orquestacion de contenedores. Se encarga de desplegar, escalar y gestionar automaticamente aplicaciones en contenedores (Docker). Es el estandar del sector para gestionar microservicios en produccion. |
| **Cluster de Kubernetes** (k8s) | Un grupo de maquinas gestionadas por Kubernetes, que se encarga de arrancar, parar y escalar contenedores automaticamente. |
| **AKS** (Azure Kubernetes Service) | Kubernetes gestionado por Azure. Azure se encarga del control plane (la parte de gestion) y tu solo administras los nodos de aplicacion. |
| **Node Pool** | Grupo de nodos (maquinas virtuales) dentro de un cluster AKS que comparten la misma configuracion (SKU, OS, tamanyo). Se pueden tener varios node pools para distintos tipos de cargas de trabajo. |
| **Pod** | La unidad minima en Kubernetes: un conjunto de uno o mas contenedores que corren juntos en el mismo nodo y comparten red y almacenamiento. |
| **Namespace** (k8s) | Division logica dentro de un cluster Kubernetes para aislar recursos entre equipos, proyectos o entornos (ej: `dev`, `prod`, `monitoring`). |
| **Ingress** (k8s) | Recurso de Kubernetes que gestiona el trafico HTTP/HTTPS entrante hacia los servicios del cluster. Hace de proxy inverso y enruta segun la URL. |
| **Helm** | Gestor de paquetes para Kubernetes. Un "chart" de Helm es un paquete que contiene todos los manifiestos YAML necesarios para desplegar una aplicacion. |
| **kubectl** | Herramienta de linea de comandos para interactuar con un cluster Kubernetes (ver pods, hacer deploys, ver logs, etc.). |
| **Dispatcher** | Componente que recibe tareas o peticiones y las reparte entre los trabajadores disponibles. Como el maitre de un restaurante. |

---

## Redes

| Termino | Explicacion rapida |
|---------|-------------------|
| **VPC** (Virtual Private Cloud) | Red privada virtual en AWS. Es el "edificio" dentro del cual viven tus servidores, aislado del resto de internet. |
| **VNet** (Virtual Network) | Lo mismo que VPC pero en Azure. Una red privada virtual donde viven las maquinas de Azure. |
| **Spoke** | En arquitecturas hub-and-spoke, el spoke es una red secundaria que se conecta a una red central (hub). El hub suele tener los servicios compartidos (seguridad, DNS) y los spokes son los entornos (stage, prod, etc.). |
| **Express Route** | Conexion de red privada y dedicada entre las oficinas de la empresa (on-prem) y Azure. Mas rapido y seguro que ir por internet normal. Es el equivalente de Azure a AWS Direct Connect. |
| **Tenant** | La instancia de Azure Active Directory (Entra ID) de una organizacion. Es el "contenedor raiz" de todos los usuarios, grupos, aplicaciones y suscripciones de Azure de la empresa. Cada empresa tiene un tenant unico identificado por un `tenant_id`. En SISCLD, el tenant engloba todas las suscripciones de dev, prod, entra y management groups. |

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
| **Drift** | Diferencia entre lo que dice el codigo Terraform (y su state) y lo que existe realmente en la nube. Ocurre cuando alguien cambia algo manualmente en el portal de Azure/AWS sin tocar el `.tf`. Se detecta con `terraform plan` — si muestra cambios sin que hayas tocado el codigo, hay drift. |
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
