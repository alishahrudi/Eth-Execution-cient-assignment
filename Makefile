.PHONY: help cluster all-local ingress-local metallb-local deploy-eth-local deploy-monitoring-local summary destroy

CLUSTER_NAME = ethereum-cluster
NAMESPACE = ethereum
HELM_RELEASE = ethereum-node

help:
	@echo "Ethereum Node Infra - KIND Deployment"
	@echo ""
	@echo "Targets:"
	@echo "  make all-local            - Full local deployment (cluster + MetalLB + ingress + monitoring + Geth)"
	@echo "  make cluster              - Create kind cluster"
	@echo "  make ingress-local        - Install NGINX ingress"
	@echo "  make metallb-local        - Install MetalLB and configure IP pool"
	@echo "  make deploy-monitoring-local - Deploy Prometheus + Grafana"
	@echo "  make deploy-eth-local     - Deploy Ethereum node (Geth)"
	@echo "  make summary              - Show Deployment summary"
	@echo "  make destroy              - Delete KIND cluster"


all-local: cluster metallb-local ingress-local deploy-monitoring-local deploy-eth-local summary

cluster:
	@command -v kind >/dev/null 2>&1 || { echo "❌ 'kind' is not installed. Please install it first."; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ 'kubectl' is not installed. Please install it first."; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "❌ 'helm' is not installed. Please install it first."; exit 1; }

	@echo "🔧 Creating kind cluster..."
	@kind create cluster --config local/kind-config.yaml || echo "⚠️ Cluster already exists"
	@kubectl cluster-info


ingress-local:
	@echo "🚀 Installing ingress-nginx..."
	helm upgrade --install ingress-nginx ./charts/nginx-ingress --namespace ingress-nginx --create-namespace --values ./charts/nginx-ingress/values.local.yaml
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/instance=ingress-nginx --timeout=120s

metallb-local:
	@echo "🚀 Installing MetalLB..."
	helm upgrade --install metallb ./charts/metallb --namespace metallb-system --create-namespace --values ./charts/metallb/values.local.yaml
	@echo "⏳ Waiting for MetalLB pods to be ready..."
	kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
	sudo chmod +x ./scripts/configure-metallb.sh
	./scripts/configure-metallb.sh

deploy-monitoring-local:
	@echo "📈 Deploying monitoring stack..."
	helm upgrade --install prom ./charts/kube-prometheus-stack --namespace monitoring --create-namespace --values ./charts/kube-prometheus-stack/values.local.yaml

deploy-eth-local:
	@echo "⛓ Deploying Ethereum node..."
	sudo chmod +x ./scripts/*.sh
	./scripts/install-sealed-secret.sh
	./scripts/isntall-kubeseal.sh
	./scripts/create-sealed-secret.sh
	helm upgrade --install $(HELM_RELEASE) ./charts/geth-node --namespace $(NAMESPACE) --create-namespace -f charts/geth-node/values.local.yaml

deploy-helios-local:cluster
	@echo "⛓ build helios node..."
	docker build -t oumla-helios-test:v1 ./local/
	kind load docker-image oumla-helios-test:v1 --name ethereum-cluster

summary:
	./scripts/summary.sh

destroy:
	@echo "🔥 Deleting KIND cluster..."
	kind delete cluster --name $(CLUSTER_NAME)

query:
	@echo "TODO: add tests api"