# Configure Terraform version and AzureRM provider requirements
terraform {
  # Enforce Terraform version between 1.0.0 and 2.0.0
  required_version = ">= 1.0.0, < 2.0.0"

  # Define required provider versions and sources
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Configure the Azure provider
provider "azurerm" {
  features {}
}

# All Azure resources must live inside a Resource Group
resource "azurerm_resource_group" "app" {
  name     = "web-server-rg"
  location = "West Europe"
}

# Virtual Network
resource "azurerm_virtual_network" "app" {
  name                = "web-server-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
}

# Subnet inside the VNet
resource "azurerm_subnet" "app" {
  name                 = "web-server-subnet"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP to reach the server from the internet
resource "azurerm_public_ip" "app" {
  name                = "web-server-pip"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  allocation_method   = "Static"
}

# Network Interface Card (NIC)
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

# Configure the VM with Ubuntu and start Apache web server
resource "azurerm_linux_virtual_machine" "app" {
  name                = "web-server-vm"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  size                = "Standard_B1s"  # equivalent to t2.micro
  admin_username      = "adminuser"

  network_interface_ids = [azurerm_network_interface.app.id]

  # Equivalent to AWS user_data: runs on first boot
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