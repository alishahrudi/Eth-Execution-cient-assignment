#!/bin/bash

echo ""
echo "📦 Gathering global summary..."

# Get LoadBalancer IP or hostname from ingress-nginx
LB_IP=$(kubectl get svc ingress-nginx-nginx-ingress-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [[ -z "$LB_IP" ]]; then
  LB_IP=$(kubectl get svc ingress-nginx-nginx-ingress-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi

if [[ -z "$LB_IP" ]]; then
  echo "❌ Could not retrieve LoadBalancer IP/hostname. Is ingress-nginx running and provisioned?"
  exit 1
fi

# Get all ingress domains from all namespaces
echo ""
echo "🌍 Ingress hostnames across all namespaces:"
echo ""

INGRESS_INFO=$(kubectl get ingress --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"|"}{.metadata.name}{"|"}{.spec.rules[*].host}{"\n"}{end}')

if [[ -z "$INGRESS_INFO" ]]; then
  echo "⚠️  No ingress resources found."
  exit 0
fi

# Output formatted info
while IFS='|' read -r ns name host; do
  if [[ -n "$host" ]]; then
    echo "🔹 [$ns/$name] $host"
  fi
done <<< "$INGRESS_INFO"

echo ""
echo "📝 Add the following to your /etc/hosts file to test locally:"
echo ""

while IFS='|' read -r _ _ host; do
  if [[ -n "$host" ]]; then
    echo "$LB_IP    $host"
  fi
done <<< "$INGRESS_INFO"
echo ""
echo ""

# Geth P2P LoadBalancer Service Name (adjust if needed)
P2P_SERVICE_NAME="ethereum-node-geth-p2p-0"
P2P_NAMESPACE="ethereum"

# Get LoadBalancer IP or hostname
P2P_LB_IP=$(kubectl get svc "$P2P_SERVICE_NAME" -n "$P2P_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [[ -z "$P2P_LB_IP" ]]; then
  P2P_LB_IP=$(kubectl get svc "$P2P_SERVICE_NAME" -n "$P2P_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi

# Get exposed ports
P2P_PORTS=$(kubectl get svc "$P2P_SERVICE_NAME" -n "$P2P_NAMESPACE" -o jsonpath='{range .spec.ports[*]}{.port}/{.protocol}{" "}{end}')

if [[ -n "$P2P_LB_IP" ]]; then
  echo "🌐 Geth P2P Service LoadBalancer IP: $P2P_LB_IP"
  echo "🔓 Open Ports: $P2P_PORTS"
  echo ""
  echo "📝 You can use this IP and port(s) to peer or test P2P connectivity to your Geth node."
else
  echo "❌ Could not retrieve LoadBalancer IP for $P2P_SERVICE_NAME in namespace $P2P_NAMESPACE"
fi

echo ""
echo "📊 Grafana Access Info"
echo "------------------------"
echo "🔐 Global Grafana credentials:"
echo "   ▸ Username: admin"
echo "   ▸ Password: admin"
echo ""
echo "📍 Open Grafana in your browser (using one of the ingress domains above)"
echo "   and navigate to the 📊 'Go-ethereum-by-instance' dashboard in the Dashboard section."
echo ""
echo "🚀 You can now access your Ingress-exposed apps in the browser!"
echo ""