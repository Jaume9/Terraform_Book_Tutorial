# BLOQUE TERRAFORM:
# Define qué versión de Terraform y qué providers necesita este proyecto.
# Sin esto, Terraform no sabe qué plugin descargar para hablar con Azure.
# "~> 3.0" significa: acepta la 3.x pero nunca la 4.0 (evita cambios incompatibles).
terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# BLOQUE PROVIDER:
# Configura la conexión con Azure.
# "features {}" es obligatorio aunque esté vacío, es un requisito del provider azurerm.
# Las credenciales se leen automáticamente de "az login" o variables de entorno ARM_*.
provider "azurerm" {
  features {}
}

# BLOQUE RESOURCE GROUP:
# En Azure TODOS los recursos deben pertenecer a un Resource Group obligatoriamente.
# Es un contenedor lógico para agrupar, gestionar y facturar recursos relacionados.
# No existe equivalente obligatorio en AWS (allí los recursos pueden existir solos).
resource "azurerm_resource_group" "app" {
  name     = "web-server-rg"
  location = "West Europe"
}

# BLOQUE VIRTUAL NETWORK:
# Es la red privada donde vivirá la VM, equivalente a una VPC en AWS.
# Sin red la VM no tiene conectividad. En AWS Terraform usa la VPC por defecto
# automáticamente; en Azure hay que crearla explícitamente siempre.
# "address_space" define el rango total de IPs disponibles en esta red.
resource "azurerm_virtual_network" "app" {
  name                = "web-server-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
}

# BLOQUE SUBNET:
# Subdivide la VNet en segmentos más pequeños.
# La VM no se conecta directamente a la VNet, sino a una subnet dentro de ella.
# Permite aislar recursos (ej: VMs públicas en una subnet, bases de datos en otra).
resource "azurerm_subnet" "app" {
  name                 = "web-server-subnet"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.0.1.0/24"]
}

# BLOQUE PUBLIC IP:
# Sin este recurso la VM solo tendría IP privada y no sería accesible desde internet.
# En AWS la IP pública se asigna directamente en aws_instance con "associate_public_ip_address".
# En Azure es un recurso independiente que luego se enlaza a la NIC.
resource "azurerm_public_ip" "app" {
  name                = "web-server-pip"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  allocation_method   = "Static"
}

# BLOQUE NETWORK INTERFACE (NIC):
# Es la "tarjeta de red virtual" que se conecta a la VM.
# Une todos los recursos de red: subnet + IP pública → VM.
# En AWS esto es completamente implícito dentro de aws_instance.
# En Azure es un recurso obligatorio y explícito que hay que crear por separado.
resource "azurerm_network_interface" "app" {
  name                = "web-server-nic"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app.id
  }
}

# BLOQUE LINUX VIRTUAL MACHINE:
# La VM en sí. Equivalente a "aws_instance" en AWS.
# Referencia todos los recursos anteriores porque Azure no crea nada implícitamente.
# "size" define la potencia de la máquina (Standard_B1s ≈ t2.micro de AWS).
# "source_image_reference" es el equivalente a la AMI de AWS: define el SO a usar.
resource "azurerm_linux_virtual_machine" "app" {
  name                = "web-server-vm"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  size                = "Standard_B1s"  # equivalent to t2.micro
  admin_username      = "adminuser"

  network_interface_ids = [azurerm_network_interface.app.id]

  # "custom_data" es el equivalente al "user_data" de AWS.
  # Se ejecuta una sola vez en el primer arranque de la VM.
  # Azure lo requiere codificado en base64 (por eso el base64encode).
  # El script instala Apache desde cero porque Ubuntu en Azure no lo trae preinstalado.
  custom_data = base64encode(<<-EOF
                #!/bin/bash
                sudo apt-get update -y
                sudo apt-get install -y apache2
                sudo service apache2 start
                EOF
  )

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}