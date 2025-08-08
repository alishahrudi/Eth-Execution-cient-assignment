
## 🧾 Overview

This solution presents a production-capable deployment pipeline for running an Ethereum execution client with full automation, observability, and scalability considerations. It demonstrates a GitOps-friendly approach using Kubernetes-native tooling, modern IaC practices, and operator-level lifecycle awareness to manage the Ethereum node as a resilient, cloud-ready stateful service.

---

### 🧱 Ethereum Execution Client: Geth (Go-Ethereum)

The core component is the **Geth (Go-Ethereum)** execution client, selected for the following reasons:

* **Performance & Maturity**: Geth is one of the most mature and battle-tested clients on the Ethereum network. Its performance and reliability make it an ideal default choice, particularly for demonstration or PoC setups where stability is critical.

* **Documentation & Community Support**: Rich official documentation and widespread usage provide a broad surface for self-service debugging and customization.

* **Ease of Bootstrapping**: Geth offers prebuilt Docker images, well-defined CLI flags, and minimal dependency overhead, which accelerates integration into Kubernetes-native environments via Helm or Kustomize.

#### ⚠️ Client Diversity Consideration

> In production, relying solely on Geth presents systemic risk. Since Geth holds over 70%+ client share on Ethereum mainnet, it becomes a **centralization and failure domain** concern. A network-critical bug in Geth could threaten consensus. Therefore, best practice in production would recommend running **minority clients** such as Nethermind, Erigon, or Besu to contribute to client diversity and network resilience.

---

### 🌐 Network: Sepolia Testnet & Snap Sync Mode

#### ✅ Network Selection: Sepolia

The **Sepolia testnet** is chosen over other testnets (e.g., Goerli) due to its:

* **EVM Equivalence**: Matches mainnet-level consensus and behavior
* **Stable Validator Set**: Ensures faster block finality and reduced re-orgs
* **Resource Efficiency**: Lower hardware requirements make it ideal for ephemeral testing environments

#### 🔄 Sync Mode: Snap Sync

Geth’s **light sync mode** has been deprecated, and as such, this deployment uses **snap sync**, which offers:

* Rapid state syncing via snapshot acquisition
* No need for full block-by-block replay
* Reduced disk and CPU I/O
* Suitable for read-heavy use cases like querying chain data via RPC

The sync mode is explicitly configured via the `--syncmode=snap` flag in the Helm values.

---

### 🚀 Local Deployment with Helm (GitOps Baseline)

The local deployment is containerized and deployed using **Helm**, offering a minimal GitOps baseline with:

* **Templated Kubernetes Manifests**: All Kubernetes resources (e.g., StatefulSet, Services, ConfigMaps) are defined as parameterized templates
* **Values Injection**: Helm allows the use of `values.yaml` and override files for environment-specific customization (e.g., resource limits, ports, storageClass)

#### 🛠 GitOps Readiness

While Argo CD is not integrated in the local setup, Helm provides enough **GitOps baseline primitives** to simulate declarative rollouts, rollback, and version-controlled manifests in a test/dev environment.

---

### ☸️ Production Deployment: Terraform + Argo CD (Recommended)

For production, I propose an architecture using:

* **Terraform** to provision infrastructure primitives (e.g., GKE clusters, service accounts, networking resources, persistent disks)
* **Argo CD** to reconcile the live Kubernetes state from a Git repository, enabling:

  * Declarative delivery of Helm charts or Kustomize overlays
  * Multi-env support (dev/staging/prod) via ApplicationSets
  * Access control and drift detection

Argo CD improves traceability, enables safe rollouts (canary, blue-green), and enforces source-of-truth principles for infrastructure and application state.

---

### 📡 Service Exposure: MetalLB + Ingress-NGINX (for KinD)

Since KinD does not natively support cloud LoadBalancer objects, **MetalLB** is integrated to simulate L2/L3 LoadBalancer behavior for on-premise or local environments.

* **MetalLB** enables Kubernetes Services of type `LoadBalancer` to function correctly by allocating local IPs from a configured pool
* **Ingress-NGINX** provides L7 routing and allows defining ingress routes for external access to Ethereum’s HTTP-RPC and WebSocket endpoints

This design ensures that the Ethereum node is accessible externally while keeping the setup realistic for what would be implemented in a cloud provider (e.g., GCP LoadBalancer + HTTPS ingress).

---

### 📈 Observability: kube-prometheus-stack

To meet the requirements of centralized monitoring and alerting, I’ve integrated the **kube-prometheus-stack**, which bundles:

* **Prometheus** for time-series metric scraping and alert rule evaluation
* **Alertmanager** for alert routing, grouping, and notification dispatch (Slack, email, PagerDuty)
* **Grafana** for visualization, using preconfigured dashboards
* **CRDs** for PrometheusRule and ServiceMonitor, enabling fully declarative observability pipelines

This stack provides a **Kubernetes-native monitoring solution** and adheres to the Prometheus Operator pattern, ensuring:

* Consistent lifecycle management of monitoring resources
* Scalability with minimal manual configuration
* GitOps compatibility via Helm or Argo CD

---

### 💾 Backup & Recovery: VolumeSnapshot (Planned)

In a production scenario, persistent volumes (PVCs) attached to Ethereum nodes should be periodically backed up using **Kubernetes VolumeSnapshot CRDs**, supported by CSI drivers (e.g., GCP PD, EBS, or Ceph).

Benefits:

* **Instantaneous snapshots** of block data volume
* **Incremental support** (depending on the storage backend)
* **Disaster recovery workflows**: Snapshots can be restored into a new PVC and reattached to a pod

The recovery logic can be integrated into CronJobs or event-driven pipelines with additional tools like Velero.

---

### 🧰 Developer Experience & Automation: Makefile

The `Makefile` abstracts the operational complexity by exposing high-level targets for local workflows:

```bash
	make all-local            - Full local deployment (cluster + MetalLB + ingress + monitoring + Geth)"
	make cluster              - Create kind cluster"
	make ingress-local        - Install NGINX ingress"
	make metallb-local        - Install MetalLB and configure IP pool"
	make deploy-monitoring-local - Deploy Prometheus + Grafana"
	make deploy-eth-local     - Deploy Ethereum node (Geth)"
	make summary              - Show Deployment summary"
	make destroy              - Delete KIND cluster"
```

Advantages:

* Enforces a repeatable interface for bootstrapping/testing
* Reduces cognitive load for reviewers or new contributors
* Encourages consistent workflows aligned with CI pipelines

