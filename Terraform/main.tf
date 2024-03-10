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
  #  dns_servers         = ["8.8.8.8"]
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
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # security rule to all outbound traffic on all protocols and all ports
  security_rule {
    name                       = "all-outbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
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
    public_ip_address_id          = azurerm_public_ip.public_ip.id
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
  size                  = "Standard_B2ts_v2" #"Standard_DS1_v2" #"Standard_A1_v2"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.linux_nic.id]

  user_data = base64encode(
    <<-EOF
    #!/bin/bash
    exec > >(tee /tmp/install.log)
    echo "Hello, World"
    apt-get update -y
    apt-get install -y apache2
    systemctl start apache2
    systemctl enable apache2
    apt-get install -y stress
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
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

# azurerm_network_security_group for SSH to var.My_ip_address
resource "azurerm_network_security_group" "ssh_nsg" {
  name                = "${random_pet.random_pet.id}-ssh-nsg"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = jsondecode(data.http.my_public_ip.body)["origin"]
    destination_address_prefix = "*"
  }
  # add security rule to open port 80 to all Inbound traffic
  security_rule {
    name                       = "http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "all-outbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# azurerm_network_interface_security_group_association for nic
resource "azurerm_network_interface_security_group_association" "ssh_nic" {
  network_interface_id      = azurerm_network_interface.linux_nic.id
  network_security_group_id = azurerm_network_security_group.ssh_nsg.id
}


data "http" "my_public_ip" {
  url = "http://httpbin.org/ip"
  # Optional: set request_headers, request_body, etc., if necessary
}

output "local_machine_public_ip" {
  value = jsondecode(data.http.my_public_ip.body)["origin"]
}



# add a route tabnle to the azurerm_subnet for route traffic to the internet 
resource "azurerm_route_table" "public_route_table" {
  name                = "${random_pet.random_pet.id}-route-table"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location

  route {
    name           = "route1"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

# azurerm_subnet_route_table_association
resource "azurerm_subnet_route_table_association" "public_route_table_association" {
  subnet_id      = azurerm_subnet.public_subnet.id
  route_table_id = azurerm_route_table.public_route_table.id
}

#----------------------------------------------------------


resource "azurerm_monitor_action_group" "action_group" {
  name                = "example-actiongroup"
  resource_group_name = azurerm_resource_group.resource_group.name
  short_name          = "exampleag"

  email_receiver {
    name                    = "sendtoexample"
    email_address           = var.action_group_email_address
    use_common_alert_schema = true
  }

}

#----------------------------------------------------------
# Metric Alert
# ---------------------------------------------------------
resource "azurerm_monitor_metric_alert" "high-cpu-alert" {
  name                 = "high-cpu-alert"
  resource_group_name  = azurerm_resource_group.resource_group.name
  scopes               = [azurerm_linux_virtual_machine.linux_vm.id]
  description          = "This alert will fire when CPU usage exceeds 80%"
  target_resource_type = "Microsoft.Compute/virtualMachines"

  auto_mitigate = true
  frequency     = "PT1M" # Possible values are PT1M, PT5M, PT15M, PT30M and PT1H. Defaults to PT1M.

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 25
  }

  action {
    action_group_id = azurerm_monitor_action_group.action_group.id
  }

  tags = {
    environment = "dev"
  }
}
