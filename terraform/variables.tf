# Azure Region
variable "azure_region" {
  type        = string
  description = "Azure region where resources will be created"
  default     = "eastus"

  validation {
    condition     = contains(["eastus", "westus", "westus2", "centralus", "northeurope", "westeurope"], var.azure_region)
    error_message = "Please choose a valid Azure region."
  }
}

# Resource Group Name
variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group"
  default     = "olake-rg"
}

# VM Name
variable "vm_name" {
  type        = string
  description = "Name of the Azure VM"
  default     = "olake-vm"

  validation {
    condition     = length(var.vm_name) <= 15 && can(regex("^[a-z0-9-]+$", var.vm_name))
    error_message = "VM name must be 15 chars or less and contain only lowercase letters, numbers, and hyphens."
  }
}

# VM Size (4 vCPU, 16GB RAM minimum)
variable "vm_size" {
  type        = string
  description = "Azure VM size (SKU)"
  default     = "Standard_D4s_v3" # 4 vCPUs, 16GB RAM

  validation {
    condition     = contains(["Standard_D4s_v3", "Standard_D4s_v5", "Standard_D4as_v4"], var.vm_size)
    error_message = "Please choose a suitable VM size with at least 4 vCPUs and 8GB RAM."
  }
}

# OS Disk Size
variable "os_disk_size_gb" {
  type        = number
  description = "Size of the OS disk in GB (minimum 50GB)"
  default     = 50

  validation {
    condition     = var.os_disk_size_gb >= 50
    error_message = "OS disk size must be at least 50GB."
  }
}

# Admin Username
variable "admin_username" {
  type        = string
  description = "Admin username for VM"
  default     = "azureuser"

  validation {
    condition     = length(var.admin_username) >= 1 && length(var.admin_username) <= 64
    error_message = "Admin username must be between 1 and 64 characters."
  }
}

# SSH Public Key Path
variable "ssh_public_key_path" {
  type        = string
  description = "Path to your SSH public key file (e.g., ~/.ssh/terraform_rsa.pub)"

  validation {
    condition     = can(file(var.ssh_public_key_path))
    error_message = "SSH public key file not found. Please provide a valid path."
  }
}

# Local Machine IP (for SSH security)
variable "local_machine_ip" {
  type        = string
  description = "Your local machine IP for SSH access (restrict port 22)"
  default     = "0.0.0.0/0" # WARNING: Change to your IP like "203.0.113.0/32" for security
}

# Environment Tag
variable "environment" {
  type        = string
  description = "Environment name for tagging resources"
  default     = "development"
}

# Project Tag
variable "project_name" {
  type        = string
  description = "Project name for tagging resources"
  default     = "OLake-DevOps-Assignment"
}

# Minikube Configuration
variable "minikube_cpus" {
  type        = number
  description = "Number of CPUs allocated to Minikube"
  default     = 3

  validation {
    condition     = var.minikube_cpus > 0 && var.minikube_cpus <= 4
    error_message = "Minikube CPUs should be between 1 and 4."
  }
}

variable "minikube_memory" {
  type        = number
  description = "Memory allocated to Minikube (in MB)"
  default     = 6144

  validation {
    condition     = var.minikube_memory >= 4096
    error_message = "Minikube memory must be at least 4096MB (4GB)."
  }
}

# OLake Namespace
variable "olake_namespace" {
  type        = string
  description = "Kubernetes namespace for OLake deployment"
  default     = "olake"
}

# OLake Helm Chart Configuration
variable "olake_helm_repo" {
  type        = string
  description = "OLake Helm chart repository URL"
  default     = "https://datazip-inc.github.io/olake-helm"
}

variable "olake_helm_chart_name" {
  type        = string
  description = "OLake Helm chart name"
  default     = "olake"
}

variable "olake_helm_chart_version" {
  type        = string
  description = "OLake Helm chart version"
  default     = "" # Leave empty for latest
}

variable "olake_release_name" {
  type        = string
  description = "Helm release name for OLake"
  default     = "olake-release"
}
