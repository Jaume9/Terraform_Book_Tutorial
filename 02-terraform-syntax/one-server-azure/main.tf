terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

# En Azure todo recurso necesita un Resource Group
resource "azurerm_resource_group" "example" {
  name     = "terraform-example-rg"
  location = "West Europe"
}

# Red virtual
resource "azurerm_virtual_network" "example" {
  name                = "terraform-example-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

# Subred
resource "azurerm_subnet" "example" {
  name                 = "terraform-example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Tarjeta de red (NIC)
resource "azurerm_network_interface" "example" {
  name                = "terraform-example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Máquina virtual
resource "azurerm_linux_virtual_machine" "example" {
  name                            = "terraform-example"
  location                        = azurerm_resource_group.example.location
  resource_group_name             = azurerm_resource_group.example.name
  size                            = "Standard_B1s"   # ~t2.micro, el más barato en Azure
  admin_username                  = "adminuser"
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.example.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"   # HDD estándar, el más barato
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Name = "terraform-example"
  }
}