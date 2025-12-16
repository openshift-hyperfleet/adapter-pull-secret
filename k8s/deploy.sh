#!/bin/bash
set -e

NAMESPACE="hyperfleet-system"

echo "===================================="
echo "Deploying Pull Secret Job to GKE"
echo "===================================="
echo ""

# Check if kubectl is configured
echo "Checking cluster connection..."
kubectl cluster-info | head -1
echo ""

# Create namespace if it doesn't exist
echo "Creating namespace $NAMESPACE if it doesn't exist..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo ""

# Apply ServiceAccount
echo "Creating ServiceAccount with Workload Identity..."
kubectl apply -f k8s/serviceaccount.yaml
echo ""

# Wait for ServiceAccount to be created
kubectl wait --for=jsonpath='{.metadata.name}'=pullsecret-adapter sa/pullsecret-adapter -n $NAMESPACE --timeout=30s

# Apply Job
echo "Creating Job..."
kubectl apply -f k8s/job.yaml
echo ""

# Wait a moment for pod to be created
echo "Waiting for pod to be created..."
sleep 2

# Show job status
echo "Job status:"
kubectl get job pullsecret-test-job -n $NAMESPACE
echo ""

# Show pod status
echo "Pod status:"
kubectl get pods -l app=pullsecret-adapter -n $NAMESPACE
echo ""

# Wait for job to complete (optional - can comment out if you want to just deploy and check manually)
echo "Waiting for job to complete (this may take a minute)..."
kubectl wait --for=condition=complete --timeout=120s job/pullsecret-test-job -n $NAMESPACE || \
kubectl wait --for=condition=failed --timeout=10s job/pullsecret-test-job -n $NAMESPACE || true
echo ""

# Get pod name
POD_NAME=$(kubectl get pods -l app=pullsecret-adapter -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POD_NAME" ]; then
  echo "Warning: No pod found yet. Use 'kubectl get pods -l app=pullsecret-adapter -n $NAMESPACE' to check status."
  POD_NAME="<pod-name>"
fi

echo "===================================="
echo "Job deployed successfully!"
echo "===================================="
echo ""
echo "Monitor job progress:"
echo "  kubectl get job pullsecret-test-job -n $NAMESPACE -w"
echo ""
echo "View logs:"
echo "  kubectl logs -f $POD_NAME -n $NAMESPACE"
echo ""
echo "Check job status:"
echo "  kubectl describe job pullsecret-test-job -n $NAMESPACE"
echo ""
echo "Delete job when done:"
echo "  kubectl delete job pullsecret-test-job -n $NAMESPACE"
echo ""
