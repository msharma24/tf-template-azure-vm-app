output "pet_name" {
  value = random_pet.random_pet.id
}

output "resource_group_name" {
  value = azurerm_resource_group.resource_group.name

}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name

}

output "subnet_name" {
  value = azurerm_subnet.public_subnet.name

}

output "nsg_name" {
  value = azurerm_network_security_group.publc_nsg.name

}


# azurerm_linux_virtual_machine" output
output "vm_name" {
  value = azurerm_linux_virtual_machine.linux_vm.name
}

output "vm_admin_username" {
  value = azurerm_linux_virtual_machine.linux_vm.admin_username
}

output "vm_admin_password" {
  value = nonsensitive(azurerm_linux_virtual_machine.linux_vm.admin_password)
}

# azurerm_linux_virtual_machine. public IP addres
output "vm_public_ip" {
  value = azurerm_linux_virtual_machine.linux_vm.public_ip_address
}
