#!/bin/bash

set -e

NAMESPACE="metallb-system"
POOL_NAME="kind-pool"
ADVERT_NAME="kind-l2"
RESERVED_RANGE=10

echo "🔍 Detecting KIND Docker IPv4 subnet..."

# Get the IPv4 subnet only (ignores IPv6)
SUBNET=$(docker network inspect kind -f '{{range .IPAM.Config}}{{if eq .Subnet ""}}{{else}}{{.Subnet}}{{end}}{{end}}' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+')

if [[ -z "$SUBNET" ]]; then
  echo "❌ Unable to detect IPv4 subnet from 'kind' network."
  exit 1
fi

BASE_IP=$(echo "$SUBNET" | cut -d'.' -f1-3)
START=240
END=$((START + RESERVED_RANGE - 1))

IP_RANGE="${BASE_IP}.${START}-${BASE_IP}.${END}"
echo "✅ Using MetalLB IPv4 range: $IP_RANGE"

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

echo "✅ MetalLB configured with IPv4 range: $IP_RANGE"
