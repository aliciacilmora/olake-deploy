#!/bin/bash

# OLake Helm Deployment Script
# This script deploys OLake using Helm after Minikube is ready
# Run this script from the terraform directory on the Azure VM or locally

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="olake"
RELEASE_NAME="olake-release"
HELM_REPO="https://datazip-inc.github.io/olake-helm"
HELM_CHART="olake"
VALUES_FILE="values.yaml"
CHART_VERSION=""  # Leave empty for latest

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    log_info "kubectl found: $(kubectl version --client --short)"

    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "Helm not found. Please install Helm."
        exit 1
    fi
    log_info "Helm found: $(helm version --short)"

    # Check Minikube status (if on VM)
    if command -v minikube &> /dev/null; then
        if ! minikube status | grep -q "Running"; then
            log_error "Minikube is not running. Please start Minikube first."
            exit 1
        fi
        log_info "Minikube is running"
    fi
}

# Verify Kubernetes cluster connectivity
verify_cluster_connection() {
    log_info "Verifying Kubernetes cluster connectivity..."

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check kubeconfig."
        exit 1
    fi

    log_info "✓ Connected to cluster: $(kubectl cluster-info | grep 'Kubernetes master')"
}

# Check cluster readiness
check_cluster_readiness() {
    log_info "Checking cluster readiness..."

    # Wait for nodes to be ready
    if ! kubectl wait --for=condition=Ready node --all --timeout=300s 2>/dev/null; then
        log_warn "Nodes not ready yet, but continuing..."
    fi

    # Check CoreDNS
    local coredns_ready=$(kubectl get pods -n kube-system | grep coredns | grep Running | wc -l)
    if [ "$coredns_ready" -eq 0 ]; then
        log_error "CoreDNS not ready. Cluster may not be fully initialized."
        exit 1
    fi

    log_info "✓ Cluster is ready"
}

# Create namespace
create_namespace() {
    log_info "Creating namespace: $NAMESPACE"

    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_warn "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace $NAMESPACE
        log_info "✓ Namespace created"
    fi
}

# Add Helm repository
add_helm_repo() {
    log_info "Adding Helm repository: $HELM_REPO"

    helm repo add olake $HELM_REPO
    helm repo update

    log_info "✓ Helm repository added and updated"
}

# Validate values file
validate_values_file() {
    if [ ! -f "$VALUES_FILE" ]; then
        log_warn "Values file ($VALUES_FILE) not found. Using default values."
        return
    fi

    log_info "Values file found: $VALUES_FILE"
}

# Deploy OLake
deploy_olake() {
    log_info "Deploying OLake Helm chart..."

    local install_cmd="helm install $RELEASE_NAME olake/$HELM_CHART \
        -n $NAMESPACE \
        --create-namespace"

    # Add chart version if specified
    if [ -n "$CHART_VERSION" ]; then
        install_cmd="$install_cmd --version $CHART_VERSION"
    fi

    # Add values file if it exists
    if [ -f "$VALUES_FILE" ]; then
        install_cmd="$install_cmd -f $VALUES_FILE"
    fi

    # Execute install command
    eval "$install_cmd"

    log_info "✓ OLake deployed successfully"
}

# Wait for deployment
wait_for_deployment() {
    log_info "Waiting for OLake deployment to be ready..."

    if kubectl rollout status -n $NAMESPACE statefulset/$HELM_CHART --timeout=600s 2>/dev/null; then
        log_info "✓ Deployment is ready"
    elif kubectl rollout status -n $NAMESPACE deployment/$HELM_CHART --timeout=600s 2>/dev/null; then
        log_info "✓ Deployment is ready"
    else
        log_warn "Deployment status check timed out or no rollout found"
    fi
}

# Display deployment status
show_deployment_status() {
    log_info "Deployment Status:"
    echo ""
    echo "Pods:"
    kubectl get pods -n $NAMESPACE

    echo ""
    echo "Services:"
    kubectl get svc -n $NAMESPACE

    echo ""
    echo "Helm Releases:"
    helm list -n $NAMESPACE
}

# Display access information
show_access_info() {
    log_info "Access Information:"
    echo ""

    local olake_service_type=$(kubectl get svc -n $NAMESPACE -o jsonpath='{.items[0].spec.type}' 2>/dev/null || echo "Unknown")
    local olake_port=$(kubectl get svc -n $NAMESPACE -o jsonpath='{.items[0].spec.ports[0].port}' 2>/dev/null || echo "8000")
    local olake_node_port=$(kubectl get svc -n $NAMESPACE -o jsonpath='{.items[0].spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")

    echo "Service Type: $olake_service_type"
    echo "Service Port: $olake_port"

    if [ "$olake_service_type" = "NodePort" ]; then
        echo "NodePort: $olake_node_port"
        echo ""
        echo "Access OLake UI:"
        echo "  - Get Minikube IP: minikube ip"
        echo "  - URL: http://<minikube-ip>:$olake_node_port"
    elif [ "$olake_service_type" = "LoadBalancer" ]; then
        echo "Note: For Minikube, use: minikube service $HELM_CHART -n $NAMESPACE"
    fi

    echo ""
    echo "Get pod logs:"
    echo "  kubectl logs -n $NAMESPACE -l app=$HELM_CHART --tail=50"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying OLake deployment..."

    local pod_count=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)
    if [ "$pod_count" -eq 0 ]; then
        log_error "No pods found in $NAMESPACE namespace"
        return 1
    fi

    local running_pods=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers | wc -l)
    log_info "Pods: $running_pods/$pod_count running"

    local failed_pods=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Failed --no-headers | wc -l)
    if [ "$failed_pods" -gt 0 ]; then
        log_error "Found $failed_pods failed pods"
        kubectl get pods -n $NAMESPACE --field-selector=status.phase=Failed
        return 1
    fi

    log_info "✓ Deployment verification successful"
    return 0
}

# Cleanup on error
cleanup_on_error() {
    log_error "Deployment failed"
    echo ""
    log_info "Rolling back Helm release..."
    helm uninstall $RELEASE_NAME -n $NAMESPACE || true

    echo ""
    log_info "Debug information:"
    echo "Pods:"
    kubectl get pods -n $NAMESPACE -o wide

    echo ""
    echo "Events:"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -20

    echo ""
    echo "Pod logs (last pod):"
    local last_pod=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$last_pod" ]; then
        kubectl logs -n $NAMESPACE $last_pod --tail=50 || true
    fi

    exit 1
}

# Main execution
main() {
    log_info "Starting OLake Helm Deployment"
    echo ""

    # Set error trap
    trap cleanup_on_error ERR

    # Execute steps
    check_prerequisites
    echo ""

    verify_cluster_connection
    echo ""

    check_cluster_readiness
    echo ""

    create_namespace
    echo ""

    add_helm_repo
    echo ""

    validate_values_file
    echo ""

    deploy_olake
    echo ""

    wait_for_deployment
    echo ""

    show_deployment_status
    echo ""

    verify_deployment || cleanup_on_error
    echo ""

    show_access_info
    echo ""

    log_info "OLake deployment completed successfully!"
}

# Run main function
main
