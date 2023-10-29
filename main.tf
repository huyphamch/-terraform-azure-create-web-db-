# Azure Provider source and version being used
terraform {
  required_version = ">= 0.14.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0.2"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  tenant_id       = "bc72934d-490b-43ba-b218-ca9eadc64bea"
  subscription_id = "60980e3a-5f38-4652-8ff3-f7a7741e315e"
  features {}
}

# Create resource group to group all created Azure resources
resource "azurerm_resource_group" "rg-web" {
  name     = "rg-${var.prefix}"
  location = var.azure_location
}

# Create Virtual Network (VNET)
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.rg-web.location
  resource_group_name = azurerm_resource_group.rg-web.name
  address_space       = var.azure_vnet_prefix
}

# Create subnet for VM
resource "azurerm_subnet" "subnet-web" {
  name                 = "subnet-web-${var.prefix}"
  resource_group_name  = azurerm_resource_group.rg-web.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.azure_web_subnet_prefix
}

resource "azurerm_subnet" "subnet-db" {
  name                 = "subnet-db-${var.prefix}"
  resource_group_name  = azurerm_resource_group.rg-web.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.azure_db_subnet_prefix
}

# Create Security group and rules for web VM
resource "azurerm_network_security_group" "nsg-web" {
  name                = "nsg-web-${var.prefix}"
  location            = azurerm_resource_group.rg-web.location
  resource_group_name = azurerm_resource_group.rg-web.name
}

resource "azurerm_network_security_rule" "nsg-rdp-web-rule" {
  name                        = "rdp"
  description                 = "Allow RDP."
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-web.name
  network_security_group_name = azurerm_network_security_group.nsg-web.name
}

resource "azurerm_network_security_rule" "nsg-ssh-web-rule" {
  name                        = "ssh"
  description                 = "Allow SSH."
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-web.name
  network_security_group_name = azurerm_network_security_group.nsg-web.name
}

# Create Network interface for VM
resource "azurerm_network_interface" "nic-web" {
  name                = "nic-web-${var.prefix}"
  resource_group_name = azurerm_resource_group.rg-web.name
  location            = azurerm_resource_group.rg-web.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet-web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip-web.id
  }
}

resource "azurerm_public_ip" "pip-web" {
  name                = "pip-web-${var.prefix}"
  location            = azurerm_resource_group.rg-web.location
  resource_group_name = azurerm_resource_group.rg-web.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "nic-db" {
  name                = "nic-db-${var.prefix}"
  resource_group_name = azurerm_resource_group.rg-web.name
  location            = azurerm_resource_group.rg-web.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet-db.id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = azurerm_public_ip.pip-web.id
  }
}

# Apply Security group rules on network interface of VM
resource "azurerm_network_interface_security_group_association" "vm-sg-asoc" {
  network_interface_id      = azurerm_network_interface.nic-web.id
  network_security_group_id = azurerm_network_security_group.nsg-web.id
}

# Create Virtual Machine (VM) for public Web
resource "azurerm_windows_virtual_machine" "vm-web" {
  name                = "vm-web-${var.prefix}"
  resource_group_name = azurerm_resource_group.rg-web.name
  location            = azurerm_resource_group.rg-web.location
  size                = "Standard_D2s_v3"

  admin_username = "adminuser"
  admin_password = "Admin+123456"

  network_interface_ids = [
    azurerm_network_interface.nic-web.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

# Create Virtual Machine (VM) for private Database
resource "azurerm_linux_virtual_machine" "vm-db" {
  name                = "vm-db-${var.prefix}"
  resource_group_name = azurerm_resource_group.rg-web.name
  location            = azurerm_resource_group.rg-web.location
  size                = "Standard_D2s_v3"

  admin_username                  = "adminuser"
  admin_password                  = "Admin+123456"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic-db.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}