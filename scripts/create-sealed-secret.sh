#!/bin/bash

NAMESPACE=${1:-ethereum}
JWT_SECRET_NAME=${2:-geth-jwt-secret}

echo "🔐 Creating sealed secrets..."

# Create namespace
kubectl create namespace $NAMESPACE 2>/dev/null || true


if [[ -f ./sealed-jwt-secret.yaml ]]; then
  echo "📝 Sealed secret already exists: $SEALED_SECRET_FILE"
  echo "📦 Applying existing sealed secret..."
  kubectl apply -f ./sealed-jwt-secret.yaml
  echo "✅ Done."
  exit 0
fi

echo "🔒 No sealed secret found. Generating a new one..."

# Generate secure JWT token
JWT_TOKEN=$(openssl rand -hex 32)
echo "Generated JWT Token: $JWT_TOKEN"

# Save plain text secret (for reference - DO NOT COMMIT TO GIT!)
echo "$JWT_TOKEN" > ./plain-jwt-token.txt

# Create temporary secret file
cat > ./plain-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: $JWT_SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
data:
  jwt-token: $(printf "%s" "$JWT_TOKEN" | base64 | tr -d '\n')
EOF

# Seal the secret
echo "🔒 Sealing secret..."
kubeseal --format yaml \
  < ./plain-secret.yaml \
  > ./sealed-jwt-secret.yaml
kubectl apply -f ./sealed-jwt-secret.yaml
# Clean up temporary files
rm ./plain-secret.yaml ./plain-jwt-token.txt

echo "✅ Sealed secret created: ./sealed-jwt-secret.yaml"