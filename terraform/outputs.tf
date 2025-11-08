# Output the public IP of the VM
output "vm_public_ip" {
  description = "Public IP address of the OLake VM"
  value       = azurerm_public_ip.olake_pip.ip_address
}

# Output SSH connection string
output "ssh_connection_string" {
  description = "SSH command to connect to the VM"
  value       = "ssh -i <your-private-key> ${var.admin_username}@${azurerm_public_ip.olake_pip.ip_address}"
}

# Output resource group name
output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.olake_rg.name
}

# Output VM ID
output "vm_id" {
  description = "Azure VM Resource ID"
  value       = azurerm_linux_virtual_machine.olake_vm.id
}

# Output Minikube access information
output "minikube_access_info" {
  description = "Information for accessing Minikube on the VM"
  value       = "SSH into the VM and run: kubectl get pods -A or minikube status"
}

# Output OLake UI access information
output "olake_ui_url" {
  description = "URL to access OLake UI (after Minikube is ready)"
  value       = "http://${azurerm_public_ip.olake_pip.ip_address}:8000"
}

# Output cloud-init log location
output "cloud_init_log" {
  description = "Location of cloud-init logs on the VM for troubleshooting"
  value       = "SSH into VM and view: /var/log/cloud-init-output.log"
}

# Output Network Security Group name
output "nsg_name" {
  description = "Network Security Group name"
  value       = azurerm_network_security_group.olake_nsg.name
}

# Output VNet and Subnet information
output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.olake_vnet.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = azurerm_subnet.olake_subnet.id
}
