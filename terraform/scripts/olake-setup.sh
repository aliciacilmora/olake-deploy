#!/bin/bash
set -xe
LOG=/var/log/olake-setup.log
echo "===== Starting OLake Setup =====" | tee -a $LOG

# 1. Install Docker
echo "=== Installing Docker ===" | tee -a $LOG
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker azureuser

# 2. Install kubectl
echo "=== Installing kubectl ===" | tee -a $LOG
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 3. Install Minikube
echo "=== Installing Minikube ===" | tee -a $LOG
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# 4. Install Helm
echo "=== Installing Helm ===" | tee -a $LOG
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 5. Start Minikube
echo "=== Starting Minikube ===" | tee -a $LOG
sudo -u azureuser bash <<'EOF'
export HOME=/home/azureuser
minikube start --driver=docker --cpus=4 --memory=8192 --force
EOF

# 6. Enable Addons
sudo -u azureuser bash <<'EOF'
export HOME=/home/azureuser
minikube addons enable ingress
minikube addons enable storage-provisioner
minikube addons enable metrics-server
EOF

# 7. Wait for ingress controller to be ready
echo "=== Waiting for ingress-nginx controller to be ready ===" | tee -a $LOG
sudo -u azureuser bash <<'EOF'
export HOME=/home/azureuser
for i in {1..30}; do
  if kubectl get pods -n ingress-nginx 2>/dev/null | grep -q "Running"; then
    echo "Ingress controller is ready."
    break
  fi
  echo "Waiting for ingress controller... ($i/30)"
  sleep 10
done
EOF

echo "=== Checking ingress webhook service endpoints ===" | tee -a $LOG
for i in {1..24}; do  # total 2 minutes with 5s interval
  endpoints=$(kubectl get endpoints ingress-nginx-controller-admission -n ingress-nginx -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "")
  if [ -n "$endpoints" ]; then
    echo "Ingress webhook endpoints ready at $endpoints" | tee -a $LOG
    break
  fi
  echo "Waiting for webhook endpoints... ($i/24)" | tee -a $LOG
  sleep 5
done

# 8. Deploy OLake
sudo -u azureuser bash <<'EOF'
export HOME=/home/azureuser
helm repo add olake https://datazip-inc.github.io/olake-helm
helm repo update
cat <<VALUES > /home/azureuser/values.yaml
olakeUI:
  ingress:
    enabled: true
    className: "nginx"
    hosts:
      - host: olake.local
        paths:
          - path: /
            pathType: Prefix
  service:
    type: ClusterIP
VALUES
helm install olake olake/olake -f /home/azureuser/values.yaml
EOF

# 9. Wait for OLake UI pod to be ready
echo "=== Waiting for OLake UI pod to be ready ===" | tee -a $LOG
sudo -u azureuser bash <<'EOF'
export HOME=/home/azureuser
for i in {1..30}; do
  if kubectl get pods | grep -q "olake-ui" && kubectl get pods | grep "olake-ui" | grep -q "Running"; then
    echo "OLake UI pod is running!"
    break
  fi
  echo "Waiting for OLake UI pod... ($i/30)"
  sleep 10
done
EOF

# 10. Port-forward OLake UI
sudo -u azureuser bash <<'EOF'
export HOME=/home/azureuser
nohup kubectl port-forward svc/olake-ui 8000:8000 --address=0.0.0.0 >/home/azureuser/port-forward.log 2>&1 &
EOF

echo "===== OLake Setup Completed =====" | tee -a $LOG
