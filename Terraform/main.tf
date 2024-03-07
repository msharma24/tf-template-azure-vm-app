resource "random_pet" "random_pet" {
  length    = 5
  separator = "-"
}

#----------------------------------------------------------
# Resource Group
# ---------------------------------------------------------
resource "azurerm_resource_group" "resource_group" {
  name     = "${random_pet.random_pet.id}-rg"
  location = "australiaeast"
}

#----------------------------------------------------------
# VNET
# ---------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${random_pet.random_pet.id}-virtualNetwork1"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4"]
}

#----------------------------------------------------------
# NSG
# ---------------------------------------------------------
resource "azurerm_network_security_group" "publc_nsg" {
  name                = "acceptanceTestSecurityGroup1"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location

  security_rule {
    name                       = "test-123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#----------------------------------------------------------
# Public Subnet
#---------------------------------------------------------
resource "azurerm_subnet" "public_subnet" {
  name                 = "${random_pet.random_pet.id}-public-subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

}

resource "azurerm_subnet_network_security_group_association" "nsg_pubic_subnet" {
  subnet_id                 = azurerm_subnet.public_subnet.id
  network_security_group_id = azurerm_network_security_group.publc_nsg.id
}

resource "azurerm_network_interface" "linux_nic" {
  name                = "${random_pet.random_pet.id}-nic"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name



  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

#azurerm_public_ip
resource "azurerm_public_ip" "public_ip" {
  name                = "${random_pet.random_pet.id}-public-ip"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

# output public ip
output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}

#----------------------------------------------------------
# Virtual Machine Linux Ubuntu
# ---------------------------------------------------------
resource "azurerm_linux_virtual_machine" "linux_vm" {
  name = "${random_pet.random_pet.id}-linux-vm"

  resource_group_name   = azurerm_resource_group.resource_group.name
  location              = azurerm_resource_group.resource_group.location
  size                  = "Standard_DS1_v2"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.linux_nic.id]
  #public_ip_address     = azurerm_public_ip.public_ip.ip_address


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
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
