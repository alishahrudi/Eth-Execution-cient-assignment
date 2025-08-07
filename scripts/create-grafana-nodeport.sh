#!/bin/bash

# Script to create a new NodePort service for Grafana on port 3000 for Kind access

set -e # Exit immediately if a command exits with a non-zero status.

NAMESPACE="monitoring"
EXISTING_SERVICE_NAME="prom-grafana" # Name of the existing ClusterIP service
NEW_SERVICE_NAME="prom-grafana-nodeport" # Name for the new NodePort service
DESIRED_NODE_PORT=30303

echo "🔍 Checking if the base service $EXISTING_SERVICE_NAME exists in namespace $NAMESPACE..."
if ! kubectl get service "$EXISTING_SERVICE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Error: Base service $EXISTING_SERVICE_NAME not found in namespace $NAMESPACE."
  echo "   Please ensure the kube-prometheus-stack is deployed."
  exit 1
fi

# Get the specific selector label values
SELECTOR_INSTANCE=$(kubectl get service "$EXISTING_SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.selector.app\.kubernetes\.io/instance}')
SELECTOR_NAME=$(kubectl get service "$EXISTING_SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.selector.app\.kubernetes\.io/name}')

if [ -z "$SELECTOR_INSTANCE" ] || [ -z "$SELECTOR_NAME" ]; then
  echo "❌ Error: Could not retrieve selector labels from $EXISTING_SERVICE_NAME."
  echo "   Instance label: '$SELECTOR_INSTANCE'"
  echo "   Name label: '$SELECTOR_NAME'"
  exit 1
fi

echo "🏷️  Found pod selector labels:"
echo "    app.kubernetes.io/instance: $SELECTOR_INSTANCE"
echo "    app.kubernetes.io/name: $SELECTOR_NAME"

echo "🔧 Creating new NodePort service '$NEW_SERVICE_NAME' in namespace '$NAMESPACE'..."

# Create the new NodePort service YAML using a here document with explicit indentation
# This avoids complex variable substitution within the YAML block
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: $NEW_SERVICE_NAME
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: grafana-nodeport
    created-by: kind-setup-script
spec:
  type: NodePort
  ports:
    - name: http-web
      port: 80
      protocol: TCP
      targetPort: 3000
      nodePort: $DESIRED_NODE_PORT
  selector:
    app.kubernetes.io/instance: $SELECTOR_INSTANCE
    app.kubernetes.io/name: $SELECTOR_NAME
EOF

echo "✅ New NodePort service '$NEW_SERVICE_NAME' created."

echo "📋 Verifying the new service..."
kubectl get service "$NEW_SERVICE_NAME" -n "$NAMESPACE"

echo "🌐 You should now be able to access Grafana at http://localhost:$DESIRED_NODE_PORT"
echo "   (The original service '$EXISTING_SERVICE_NAME' is unchanged)"
