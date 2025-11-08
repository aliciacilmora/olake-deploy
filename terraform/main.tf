# ---------------------------
# Resource Group
# ---------------------------
resource "azurerm_resource_group" "olake_rg" {
  name     = "rg-olake-west-europe"
  location = "West Europe"

  tags = {
    Environment = "Dev"
    Project     = "OLake"
    CreatedBy   = "Terraform"
  }
}

# ---------------------------
# Virtual Network + Subnet
# ---------------------------
resource "azurerm_virtual_network" "olake_vnet" {
  name                = "vnet-olake"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.olake_rg.location
  resource_group_name = azurerm_resource_group.olake_rg.name
}

resource "azurerm_subnet" "olake_subnet" {
  name                 = "snet-olake"
  resource_group_name  = azurerm_resource_group.olake_rg.name
  virtual_network_name = azurerm_virtual_network.olake_vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# ---------------------------
# Public IP
# ---------------------------
resource "azurerm_public_ip" "olake_pip" {
  name                = "pip-olake"
  location            = azurerm_resource_group.olake_rg.location
  resource_group_name = azurerm_resource_group.olake_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Project = "OLake"
  }
}

# ---------------------------
# Network Security Group
# ---------------------------
resource "azurerm_network_security_group" "olake_nsg" {
  name                = "nsg-olake"
  location            = azurerm_resource_group.olake_rg.location
  resource_group_name = azurerm_resource_group.olake_rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-OLakeUI"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Outbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ---------------------------
# Network Interface
# ---------------------------
resource "azurerm_network_interface" "olake_nic" {
  name                = "nic-olake"
  location            = azurerm_resource_group.olake_rg.location
  resource_group_name = azurerm_resource_group.olake_rg.name

  ip_configuration {
    name                          = "ipconfig-olake"
    subnet_id                     = azurerm_subnet.olake_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.olake_pip.id
  }
}

# Associate NSG
resource "azurerm_network_interface_security_group_association" "olake_assoc" {
  network_interface_id      = azurerm_network_interface.olake_nic.id
  network_security_group_id = azurerm_network_security_group.olake_nsg.id
}

# ---------------------------
# Linux VM with Cloud-Init
# ---------------------------
resource "azurerm_linux_virtual_machine" "olake_vm" {
  name                = "vm-olake"
  location            = azurerm_resource_group.olake_rg.location
  resource_group_name = azurerm_resource_group.olake_rg.name
  size                = "Standard_D4s_v3"
  zone                = "2"

  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/terraform_rsa.pub")
  }

  network_interface_ids = [azurerm_network_interface.olake_nic.id]

  os_disk {
    name                 = "osdisk-olake"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # --------------------------
  # Step 1: Copy script to VM
  # --------------------------
  provisioner "file" {
    source      = "${path.module}/scripts/olake-setup.sh"
    destination = "/tmp/olake-setup.sh"

    connection {
      type        = "ssh"
      user        = "azureuser"
      private_key = file("~/.ssh/terraform_rsa")
      host        = azurerm_public_ip.olake_pip.ip_address
    }
  }

  # --------------------------
  # Step 2: Run the script
  # --------------------------
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/olake-setup.sh",
      "sudo bash /tmp/olake-setup.sh"
    ]

    connection {
      type        = "ssh"
      user        = "azureuser"
      private_key = file("~/.ssh/terraform_rsa")
      host        = azurerm_public_ip.olake_pip.ip_address
    }
  }

  tags = {
    Environment = "Dev"
    Project     = "OLake"
    Owner       = "Terraform"
  }

  depends_on = [
    azurerm_network_interface_security_group_association.olake_assoc
  ]
}

