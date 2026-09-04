#!/bin/bash

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# 0. Create Kubernetes cluster with kind
print_section "Creating Kubernetes Cluster with kind"
kind create cluster --config=./cluster.yml --name=todoapp-cluster || echo "Cluster already exists or failed to create"

echo "Waiting for cluster to be ready..."
sleep 10

echo "Starting Kubernetes cluster deployment..."

# 1. Create namespaces
print_section "Creating Namespaces"
kubectl apply -f ./.infrastructure/namespace.yml
kubectl apply -f ./.infrastructure/namespace-mysql.yml

# 2. Create MySQL resources
print_section "Creating MySQL Secrets and ConfigMaps"
kubectl apply -f ./.infrastructure/secret-mysql.yml
kubectl apply -f ./.infrastructure/configMap-mysql.yml

print_section "Creating MySQL StatefulSet"
kubectl apply -f ./.infrastructure/statefulSet.yml

print_section "Creating MySQL Service"
kubectl apply -f ./.infrastructure/service-mysql.yml

# 3. Wait for MySQL to be ready
print_section "Waiting for MySQL StatefulSet to be ready..."
kubectl rollout status statefulset/mysql -n mysql --timeout=5m

# 4. Create application resources
print_section "Creating Application Secrets and ConfigMaps"
kubectl apply -f ./.infrastructure/secret.yml
kubectl apply -f ./.infrastructure/configMap.yml

print_section "Creating Persistent Volumes and Claims"
kubectl apply -f ./.infrastructure/pv.yml
kubectl apply -f ./.infrastructure/pvc.yml

# 5. Create application services
print_section "Creating Application Services"
kubectl apply -f ./.infrastructure/clusterIp.yml
kubectl apply -f ./.infrastructure/nodeport.yml

# 6. Deploy application
print_section "Deploying TodoApp"
kubectl apply -f ./.infrastructure/deployment.yml

# 7. Wait for deployment to be ready
print_section "Waiting for TodoApp deployment to be ready..."
kubectl rollout status deployment/todoapp -n todoapp --timeout=5m

# 8. Create HPA
print_section "Creating Horizontal Pod Autoscaler"
kubectl apply -f ./.infrastructure/hpa.yml

print_section "Deployment Complete!"
echo -e "${GREEN}All resources have been successfully deployed!${NC}"
echo ""
echo "To access the application:"
echo "  - NodePort: http://localhost:30007"
echo ""
echo "To view logs:"
echo "  - kubectl logs -f deployment/todoapp -n todoapp"
echo ""
echo "To check pod status:"
echo "  - kubectl get pods -n todoapp"
echo "  - kubectl get pods -n mysql"
