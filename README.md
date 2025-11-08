# OLake Azure Deployment Setup Guide

This readme details the steps used to deploy the OLake application on Azure using Terraform with Minikube Kubernetes cluster and Helm. It includes SSH key setup, Azure CLI installation, Terraform commands, and troubleshooting tips.

---

## Prerequisites

- **Azure account** with necessary permissions to create resources.
- **Azure CLI** installed and authenticated.
- **Terraform** installed on your local machine.
- **SSH key pair** generation for secure VM access.

---

## Step 1: Install and Authenticate Azure CLI

If not installed, install Azure CLI following the official instructions:

- For Ubuntu/Debian:
```
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

- For other platforms, see the official guide: [Azure CLI Installation](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

### Login and set subscription:
```
az login
az account set --subscription "{your-subscription-id}"
```

---

## Step 2: Generate SSH Key

Generate a dedicated SSH key pair for Terraform VM authentication:
```
ssh-keygen -t rsa -b 4096 -f ~/.ssh/terraform_rsa -C "terraform" -N ""
```
- Private key is `~/.ssh/terraform_rsa`
- Public key is `~/.ssh/terraform_rsa.pub`

---

## Step 3: Initialize Terraform

Configure your Terraform files with appropriate Azure provider and variables including public SSH key path, VM info, etc.

- First run Terraform plan to preview changes:
```
terraform plan -out=tfplan
```

---

## Step 4: Apply Terraform Plan

Apply the saved plan to create resources:
```
terraform apply tfplan
```
This will create the Azure Linux VM and provision OLake's Minikube Kubernetes cluster with all dependencies.

---

## Step 5: SSH into the VM

Once provisioning is complete, SSH into the Azure VM using the private SSH key:
```
ssh -i ~/.ssh/terraform_rsa azureuser@<vm_public_ip>
```
Replace `<vm_public_ip>` with the public IP output by Terraform.

---

## Step 6: Verify Setup on VM

Check Minikube and Kubernetes status:
```
minikube status
kubectl get nodes
kubectl get pods --all-namespaces
```

Check logs and ensure OLake pods are running.

---

## Additional Notes For Debug

- If Terraform plan or apply commands error with stale plans, re-run `terraform plan` to refresh.
- If SSH connection issues occur due to IP changes, update your allowed inbound IP in Azure NSG or temporarily allow all IPs (`0.0.0.0/0`) for troubleshooting.
- Use `kubectl port-forward` or expose services as NodePort for accessing OLake UI externally.
- Wait for ingress-nginx admission webhook readiness to avoid helm install failures.
- Review `/var/log/olake-setup.log` and cloud-init logs on the VM for detailed debug information.

