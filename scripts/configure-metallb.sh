#!/bin/bash

set -e

NAMESPACE="metallb-system"
POOL_NAME="kind-pool"
ADVERT_NAME="kind-l2"
RESERVED_RANGE=10

echo "🔍 Detecting KIND Docker subnet..."

SUBNET=$(docker network inspect kind -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
BASE_IP=$(echo $SUBNET | cut -d'.' -f1-3)

START=240
END=$((START + RESERVED_RANGE - 1))

IP_RANGE="${BASE_IP}.${START}-${BASE_IP}.${END}"
echo "✅ Using MetalLB IP range: $IP_RANGE"

echo "📦 Applying MetalLB IPAddressPool and L2Advertisement..."

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: $POOL_NAME
  namespace: $NAMESPACE
spec:
  addresses:
    - $IP_RANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: $ADVERT_NAME
  namespace: $NAMESPACE
EOF

echo "✅ MetalLB configured with auto-detected IP range"
