# ─── PROVIDER ───────────────────────────────────────────────
# Credenciales se leen automáticamente de:
#   - az login  (Azure CLI)
#   - Variables de entorno ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ─── RESOURCE GROUP ─────────────────────────────────────────
# En Azure todo recurso vive dentro de un Resource Group
resource "azurerm_resource_group" "example" {
  name     = "hello-world-rg"
  location = "West Europe"
}

# ─── MÁQUINA VIRTUAL ────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "example" {
  name                = "hello-world-vm"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  size                = "Standard_B1s"  # equivalente al t3.micro de AWS
  admin_username      = "adminuser"

  network_interface_ids = [azurerm_network_interface.example.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")  # tu clave SSH pública local
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

  tags = {
    Name = "hello-world"
  }
}
