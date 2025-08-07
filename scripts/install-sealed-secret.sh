#!/bin/bash

echo "🔄 Installing Sealed Secrets Controller..."

# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.2/controller.yaml

# Wait for controller to be ready
echo "⏳ Waiting for Sealed Secrets controller..."
kubectl wait --namespace kube-system --for=condition=ready pod -l name=sealed-secrets-controller --timeout=300s

# Get the controller certificate
echo "📥 Getting Sealed Secrets certificate..."
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o jsonpath='{.items[0].data.tls\.crt}' | base64 -d > /tmp/sealed-secrets-cert.pem

echo "✅ Sealed Secrets installed!"
echo "Certificate saved to: /tmp/sealed-secrets-cert.pem"