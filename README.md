# Ethereum Execution Client Infrastructure – DevOps Assessment

## Executive Summary

This repository delivers a modular, reproducible, and cloud-adaptable solution for deploying an Ethereum execution client node using modern DevOps practices. The project is designed to highlight operational maturity, automation discipline, and production-aligned architectural thinking in managing stateful blockchain infrastructure within containerized environments.

Developed as part of a Senior DevOps Engineer technical assessment, this solution focuses on:

* Declarative infrastructure and deployment
* GitOps-oriented release management
* Kubernetes-native observability
* Network resiliency and security considerations
* Extensibility to hybrid and multi-cloud environments

---

## Technology Choices and Rationale

### Execution Client: Geth

The [Go-Ethereum (Geth)](https://geth.ethereum.org/) client was selected as the execution engine for the following reasons:

* **Performance and Reliability**: Geth remains one of the most mature, performant Ethereum clients with widespread production use.
* **Operational Support**: Strong documentation and community tooling reduce the operational burden.
* **Developer Experience**: Geth’s interfaces and metrics are well-understood across ecosystems, accelerating integration with monitoring and orchestration tools.

> **Client Diversity Note**: In production environments, over-reliance on a single execution client introduces systemic risk. While Geth currently supports a majority share of the Ethereum network, it's advisable to include minority clients (e.g., Nethermind, Besu, Erigon) to reduce the likelihood of correlated failure modes.

### Synchronization Strategy: Snap Sync

In alignment with Ethereum’s client roadmap, Geth’s deprecated light sync mode is avoided in favor of **snap sync**, which offers:

* Rapid state bootstrapping via state trie snapshots
* Reduced disk I/O and sync times compared to full archival sync
* Production compatibility with both mainnet and testnet peers

Snap sync provides the optimal balance between completeness and operational efficiency for the node operator.

### Network: Sepolia Testnet

The **Sepolia test network** was chosen based on its alignment with real-world Ethereum infrastructure characteristics while maintaining low operational overhead. Advantages include:

* Full EVM equivalence and production parity
* Stable validator set managed by Ethereum Foundation
* Low cost of experimentation due to constrained gas markets and validator participation
* Fast finality and minimal chain reorganizations

This makes Sepolia ideal for simulating mainnet conditions in a cost-efficient and safe manner.

---

## Infrastructure Architecture

The solution is designed with environment-agnostic principles, suitable for deployment across:

* Local container platforms (KinD, Docker Desktop)
* Managed Kubernetes services (GKE, EKS, AKS)
* Hybrid or multi-cloud deployments via IaC modules

### Deployment Framework

* **Helm**: The primary templating engine used to deploy Geth and related components to Kubernetes. Helm provides parameterization, version control, and supports GitOps-aligned releases.
* **Makefile**: Used to standardize workflows across environments, abstract complexity, and ensure reproducibility in developer and CI/CD environments.

While Helm serves as the foundational tool for local orchestration, it is recommended that **Argo CD** be used in production environments to enable GitOps workflows, policy enforcement, and environment promotion pipelines.

### Network Exposure

* **MetalLB** is utilized to simulate L4 load balancer services within KinD environments, overcoming the lack of native load balancing support in local clusters.
* **Ingress-NGINX** provides L7 routing to expose the Ethereum JSON-RPC interfaces securely and predictably.
* These components mirror production ingress models while supporting rapid testing in local or CI contexts.
Great catch. Here’s an **addendum to your Infrastructure Architecture section** that introduces **Sealed Secrets** in an enterprise-grade way and ties it directly to your Makefile flow.

---

## Secret Management: Sealed Secrets (GitOps-safe encryption of Kubernetes Secrets)

This project uses **Bitnami Sealed Secrets** to manage sensitive configuration in a **GitOps-compatible** manner. Instead of committing raw `Secret` objects (which are merely base64-encoded), we commit **encrypted** `SealedSecret` CRs. Only the **cluster-resident controller** can decrypt them into runtime `Secret`s.

### Why Sealed Secrets

* **Safe-by-default GitOps**: Secrets are encrypted with the cluster’s **public key** and are **safe to store in Git** alongside application manifests. This preserves a single source of truth without leaking credentials.
* **Cluster-scoped trust**: Decryption requires the controller’s **private key** (stored in-cluster). Even if the repo is public or compromised, the ciphertext is useless off-cluster.
* **Drift-proof & auditable**: Secret lifecycle is fully declarative and versioned. Reviews happen via standard PR workflows; Argo CD (prod) or Helm (local) simply reconciles the desired state.
* **Namespace/name binding**: By default, a sealed secret is bound to a specific `<namespace>/<name>`. This prevents credential replay in unintended places. (Namespace-wide and cluster-wide modes exist but are restricted and should be justified.)
* **Multi-environment hygiene**: Each environment (dev/stage/prod) has its own controller certificates; sealed payloads are **not re-usable across clusters**, which naturally enforces separation of concerns.
* **Operational ergonomics**: The `kubeseal` CLI supports re-sealing, public cert retrieval, and non-interactive pipelines. Teams can rotate or re-seal without ever seeing cleartext in repos or CI logs.

### How it works (at a glance)

1. **kubeseal (client)** encrypts a vanilla Secret using the **controller’s public cert**, producing a `SealedSecret` CR.
2. **Sealed-Secrets Controller (in-cluster)** watches `SealedSecret` resources, decrypts them with its **private key**, and writes standard `Secret`s.
3. Workloads (Helm releases, Deployments, StatefulSets) reference those `Secret`s via environment variables, volumes, or chart `existingSecret` hooks.

### How this repository uses it

* The `Makefile` wires this into your local flow:

  * `deploy-eth-local` marks scripts executable (requires a narrow, one-time `sudo`) and runs:

    * `install-sealed-secret.sh` – installs the **Sealed-Secrets controller** CRD/operator
    * `isntall-kubeseal.sh` – installs the **kubeseal** CLI (typo acknowledged in filename)
    * `create-sealed-secret.sh` – generates and applies **SealedSecret** manifests for this stack
* Result: sensitive values (e.g., RPC credentials, webhook tokens, Grafana admin password, any future keys) never live as plaintext in Git. They are delivered declaratively and materialized as standard `Secret`s only inside the cluster at runtime.
* This integrates cleanly with **Helm**:

  * Charts can reference **pre-created `Secret`s** (populated by the controller) using `existingSecret` or `envFrom` patterns.
  * In Argo CD (production), apply order ensures the CRD and controller exist before application charts reconcile.

### Security model & RBAC considerations

* **Least privilege**: Only the controller can decrypt. Downstream workloads should have minimal read access to only the `Secret`s they need.
* **Scope controls**: Prefer **strict name/namespace sealing**. Use namespace-wide or cluster-wide annotations **only** for justified, well-audited use cases.
* **Key custody**: The controller’s private key (stored as a Secret in the controller’s namespace) is a **Tier-0 asset**. Treat backup/restore with the same rigor as CA keys.
* **Rotation policy**: Plan for periodic rotation of the controller keypair and re-sealing of secrets. Re-sealing can be automated via CI using the new public cert.

### Operational runbook (high level)

* **Bootstrap**: Install CRD + controller → install `kubeseal` → seal secrets → commit `SealedSecret` CRs → reconcile via Helm/Argo.
* **Backup/DR**: Back up the controller private key Secret securely. In a disaster, restore the key to allow existing `SealedSecret`s to decrypt in the rebuilt cluster.
* **Rotation**: Introduce a new keypair (controller), re-seal secrets with the new public cert, remove the old key after a grace period.
* **Migration across clusters**: Re-seal with the **target cluster’s** public cert; do not move ciphertext wholesale.

### Limitations & gotchas

* **Name/namespace immutability**: Changing a `SealedSecret`’s metadata usually requires **re-sealing**.
* **CRD ordering**: Ensure the Sealed-Secrets CRD and controller are present **before** applying `SealedSecret` resources (addressed in your Makefile’s order).
* **Binary and large payloads**: Supported, but prefer external KMS + references for very large or rotational secrets to keep Git concise and reviewable.

## Observability Stack

Comprehensive observability is achieved through the **kube-prometheus-stack**, which integrates:

* **Prometheus** for metrics collection and rule evaluation
* **Grafana** for real-time visualization and dashboarding
* **Alertmanager** for incident routing and notification management
* **Custom Resource Definitions (CRDs)** enabling GitOps-driven lifecycle control of monitoring components

Key metrics exposed by Geth (e.g., peer count, sync status, block latency) are scraped and visualized using pre-configured dashboards, and alert rules are defined to proactively signal synchronization failures or availability degradation.

---

## Production Considerations

### Infrastructure Provisioning

**Terraform** is used to define infrastructure modules and cloud resources for production environments. This includes:

* Kubernetes clusters
* Cloud load balancers and ingress controllers
* Persistent storage (e.g., GCP PD, AWS EBS)
* Identity and access management

This allows infrastructure to be treated as version-controlled code and supports integration with CI/CD and policy-as-code frameworks.

### State Management and Disaster Recovery

For backup and disaster recovery, the architecture leverages **Kubernetes VolumeSnapshots** via CSI-compliant storage providers. This enables:

* Scheduled or on-demand snapshot creation of the node's persistent state
* Integration with snapshot lifecycle controllers
* Restoration workflows aligned with node upgrade or rollback scenarios

VolumeSnapshots support cloud-native recovery and align with platform SLAs for high-availability deployments.

---

## Light Client Integration (Helios)

To illustrate Ethereum's stateless client direction and validate trust-minimized access to the execution layer, the project includes integration with [Helios](https://github.com/a16z/helios), an a16z-developed light client implemented in Rust.

Key characteristics:

* Runs independently of full nodes, relying on external execution and consensus RPC endpoints
* Validates execution state via light client sync (checkpoint and sync committee)
* Demonstrates the performance benefits of lightweight node operation for RPC consumers

Helios is deployed against Ethereum **mainnet**, providing a practical demonstration of light client operation in environments where resource constraints or security isolation are required.

---

## Design Automation and Lifecycle Management

* **Makefile** is used to automate local deployment, validation, and teardown workflows. This enforces repeatability and reduces cognitive overhead for engineers onboarding or reviewing the system.
* **Git-based release control** is supported via Helm templating, ensuring that deployments are reproducible and auditable.
* The repository layout and scripts are structured to integrate seamlessly into GitOps platforms such as **Argo CD** or **Flux CD**, enabling declarative infrastructure promotion and compliance with change management policies.

---

## Assumptions and Constraints

* Public consensus RPC endpoints are currently limited in their support for light client APIs (e.g., `/eth/v1/beacon/light_client/bootstrap`). Running a local beacon node is recommended for full Helios compatibility.
* This solution is intended to demonstrate best practices and foundational patterns. Additional features (e.g., secure secret management, TLS termination, horizontal scaling of RPC gateways) can be incorporated in production implementations.
* Full fault tolerance and HA behavior (e.g., redundant node pools, chain split protection) are out of scope but can be introduced with minimal architectural changes.

---

## Repository Structure

| Path         | Purpose                                      |
| ------------ | -------------------------------------------- |
| `charts/`    | Helm chart definitions and templates         |
| `terraform/` | Infrastructure provisioning modules          |
| `scripts/`   | Utility and lifecycle management scripts     |
| `docs/`      | Architecture documentation and design notes  |
| `helios/`    | Helios Docker configuration and launch setup |
| `Makefile`   | Local automation targets                     |

---
# Setup Instructions (Local)

This local environment uses KinD to stand up a Kubernetes cluster, exposes services via MetalLB and NGINX Ingress, deploys Geth (Sepolia, snap sync) and the monitoring stack via Helm, and optionally runs a Helios light node for comparison. The process is automated through `make` targets.
## Architecture
![Alt text](docs/local.drawio.png)
## Prerequisites

Install and have in your `PATH`:

* **make** – orchestrates the end-to-end workflow
* **helm** – deploys charts to Kubernetes
* **kind** – creates the local Kubernetes cluster in Docker
* **kubectl** – interacts with the cluster
* **terraform** – required for production provisioning (not needed for the basic local run)

> Review the `Makefile` to see each target’s behavior and dependencies.

## One-Command Local Bring-Up

```bash
make all-local
```

This performs, in order: `cluster` → `metallb-local` → `ingress-local` → `deploy-monitoring-local` → `deploy-eth-local` → `deploy-helios-local` → `summary`.

### A note about sudo/root (expected and narrowly scoped)

During `deploy-eth-local` and `metallb-local`, you may be prompted for **sudo**. This is intentionally limited to:

* Marking repo scripts as **executable** (e.g., `./scripts/*.sh`)
* Installing **kubeseal** to generate **sealed secrets**

This is a standard, safe setup step for local evaluation.

## Post-Install Summary and `/etc/hosts`

At the end of the automation, `make summary` runs automatically and prints:

* MetalLB-assigned **IP addresses**
* The **Ingress hostnames** to use locally
* Any relevant ports/credentials

Update your `/etc/hosts` using the IP shown in the summary so the local domains resolve. The summary will tell you exactly what to add; expect entries similar to:

```
<metallb-ip>  api.oumla.local helios.oumla.local
```

(Add any additional hostnames printed by the summary, e.g., a Grafana host, if present.)

## Let the node settle, then verify

Give Geth a couple of minutes to advance snap sync. Then verify connectivity and chain progress:

```bash
make query
```

This sends:

* `net_peerCount` and `eth_blockNumber` to **Geth** at `http://api.oumla.local`
* `eth_blockNumber` to **Helios** at `http://helios.oumla.local`

You should see non-error JSON-RPC responses; the block number will increase as sync progresses.

---

## Make Targets (what each one does)

* `make help`
  Prints the target catalog.

* `make all-local`
  Full local deployment: cluster + MetalLB + Ingress + monitoring + **Geth** + **Helios** + summary.

* `make cluster`
  Validates that **kind**, **kubectl**, and **helm** exist; creates the KinD cluster using `local/kind-config.yaml`; prints cluster info.

* `make ingress-local`
  Installs **NGINX Ingress** from `charts/nginx-ingress` (values: `values.local.yaml`) and waits for it to be ready.

* `make metallb-local`
  Installs **MetalLB** from `charts/metallb`, waits for controller readiness, then runs `scripts/configure-metallb.sh` (requires sudo once) to configure the address pool.

* `make deploy-monitoring-local`
  Deploys the **kube-prometheus-stack** (Prometheus, Grafana, Alertmanager) via `charts/kube-prometheus-stack` with local values.

* `make deploy-eth-local`
  Prepares scripts (sudo to `chmod +x`), installs **sealed-secrets/kubeseal**, creates a sealed secret, and deploys the **Geth** chart `charts/geth-node` into namespace `ethereum` with `values.local.yaml`.

* `make deploy-helios-local`
  Builds the **Helios** Docker image from `./local/`, loads it into KinD, and deploys the `charts/helios` chart into the `helios` namespace.

* `make summary`
  Runs `scripts/summary.sh` to print ingress hosts and service addresses you’ll need (including what to add to `/etc/hosts`).

* `make destroy`
  Deletes the KinD cluster (`ethereum-cluster`) and all local resources.

* `make query`
  Executes JSON-RPC test calls against the deployed endpoints (`api.oumla.local` and `helios.oumla.local`) to confirm service health.

---

With these steps, you get a fully functional local environment—networked, observable, and ready to validate both a snap-sync Geth execution client and a light Helios node—while mirroring the production toolchain and patterns.

You’re right—I should have called out the Terraform that’s already in your repo. Here’s an updated, **production setup** section that’s explicitly Terraform-centric and assumes your `terraform/` directory is the source of truth for cloud provisioning. It keeps the same enterprise tone and again states that **Helios/light clients are not deployed in prod**.

---

# Setup Instructions (Production)

This guide describes how to deploy the stack on **GCP (GKE)** using the **Terraform code in this repository** for platform provisioning, plus GitOps (Argo CD) and Helm for application delivery. The same pattern maps to AWS/Azure with provider swaps.

> **Light clients in production**
> Helios—and in general, Ethereum light clients—are **not production-ready** for mission-critical workloads. This production procedure **does not** deploy Helios. Use the Geth execution node path described below.

---
![Alt text](docs/gcp.drawio.png)
## 1) Provision the platform with the repo’s Terraform

All cloud primitives should come from **this repo’s Terraform** (network, GKE, storage, IAM, snapshot classes, etc.).

**Inputs you’ll typically provide:**

* Project/region/zone(s), network ranges
* GKE cluster params (regional, node pools, Workload Identity)
* Storage class defaults (PD-Balanced/PD-SSD)
* Optional DNS zone, logging/metrics toggles

**Suggested workflow:**

```bash
cd terraform/

# (Optional) Configure a remote backend such as GCS for state
# backend.tf -> gcs { bucket = "<your-tf-state-bucket>", prefix = "infra" }

terraform init
terraform workspace new prod || terraform workspace select prod
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**What this should create (via this repo’s Terraform):**

* **VPC / subnets / firewall** with least-privilege egress
* **Regional GKE** cluster + node pools (ingress / monitoring / workloads)
* **StorageClass** and **VolumeSnapshotClass** (CSI)
* **Service accounts / IAM** aligned to Workload Identity
* (Optional) **Cloud DNS** zone and GCLB prerequisites

> Keep Terraform state in a **remote backend (GCS)** with locking. Use **workspaces** or directory-based environments (e.g., `env/prod.tfvars`) for clean separation.

---

## 2) Bootstrap the “platform layer” add-ons (GitOps-friendly)

Install cluster-level add-ons that everything depends on. In production, manage these with **Argo CD** (recommended) or a one-time Helm bootstrap:

* **Sealed Secrets (Bitnami)**: controller + CRDs. Retrieve the public cert for `kubeseal`.
* **Ingress**: prefer **GKE Ingress** (L7, global) for public endpoints; NGINX is fine where required.
* **cert-manager**: ClusterIssuers (ACME/Let’s Encrypt or Google CAS) for TLS.
* **ExternalDNS** (if using Cloud DNS): annotate Services/Ingress for auto-managed DNS.

Argo CD should own the desired state (charts/manifests) in a `platform` application set so changes are PR-gated and auditable.

---

## 3) Deploy the observability stack (from this repo)

Use the **kube-prometheus-stack** Helm chart (as included in this repo) via Argo CD or Helm:

* **Prometheus/Alertmanager/Grafana** plus CRDs
* **ServiceMonitor/PodMonitor** for Geth and core add-ons
* **Alert rules** for peer count, sync lag, block import latency, RPC saturation, PV usage
* Route alerts to PagerDuty/Slack/email
* Forward logs to **Cloud Logging** with labels and retention

Values are environment-scoped (e.g., `values.prod.yaml`).

---

## 4) Secrets via Sealed Secrets (produced from this repo)

This repo already wires sealed secrets into the flow. In production:

1. Generate plaintext `Secret` YAML **locally** (never commit).
2. Run `kubeseal` against the **prod cluster’s public cert** to produce `SealedSecret` manifests.
3. Commit only the `SealedSecret` resources to Git.
4. Charts reference **existing secrets** so credentials never live in values files.

This preserves GitOps, enables audit, and avoids plaintext in repos/CI logs.

---

## 5) Deploy the Ethereum execution client (Geth) with Helm

Use the Helm chart in this repo (e.g., `charts/geth-node`) with a **production values overlay**:

* **Network**: Sepolia (prod-like) or mainnet (if business requires)
* **Sync**: `--syncmode=snap`
* **StatefulSet** + **PVC** (PD-Balanced or PD-SSD)
* **Probes**: readiness (RPC), liveness (process)
* **Resources**: sized for TPS/latency goals
* **PDB / topology spread** for HA
* **NetworkPolicy** to constrain egress/ingress
* **Ingress**: GCLB with TLS via cert-manager; DNS via ExternalDNS

**Scaling guidance:** Prefer vertical scaling for the stateful geth pod; for read QPS bursts, front with stateless RPC gateways and shard client traffic. Archive use cases require different pruning/disk profiles.

> **Not deployed in prod:** Helios/light clients. Keep them in R\&D/non-critical paths until maturity improves.

---

## 6) Backups and disaster recovery (from this repo’s design)

* Ensure **CSI VolumeSnapshot** is enabled (Terraform should have set this up).
* Define a **VolumeSnapshotClass**; schedule **periodic snapshots** (e.g., every 6–12h).
* Snapshots live in PD snapshot catalog; apply retention/immutability policies.
* **Restore drill**: create PVC from snapshot → roll a replacement pod → validate sync → shift traffic via readiness/Ingress.

For strict RPO/RTO or compliance, pair snapshots with off-cloud copies and key escrow.

---

## 7) Security and compliance posture

* **Workload Identity** (KSA↔GSA mapping), no node-level creds
* **Private cluster** + controlled egress via NAT; restrict metadata server
* **Image policy** (sign/verify), restricted registries; consider GKE Sandbox
* **NetworkPolicy**: default deny; open only peer/bootstrap egress and health/ingress
* **Sealed Secrets** only in Git; rotate controller keys; back up the private key securely
* **Audit**: API server audit logs → Cloud Logging with alerts/retention

---

## 8) Release and promotion (from this repo to prod)

* Use **Argo CD ApplicationSets** to apply the same charts into **dev → stage → prod**, driven by values files and namespaces.
* All changes are PR-gated; Argo handles rollout and drift detection.
* For risk-managed updates, use canary/blue-green where appropriate with health gates and SLO checks.

---

## What uses Terraform from this repo vs. Helm/GitOps

* **Terraform (in this repo):** networking, GKE clusters, node pools, IAM, storage, snapshot classes, DNS scaffolding.
* **Helm (in this repo) + Argo CD:** ingress/controllers, Sealed Secrets controller, kube-prometheus-stack, Geth StatefulSet and services, any per-env values.
* **Makefile:** still useful locally; in prod, CI/CD (Argo CD) becomes the orchestrator.

---

### Outcome

A regional, HA GKE cluster provisioned by **your Terraform**, secured and observable; **Sealed Secrets** for GitOps-safe credentials; **kube-prometheus-stack** for chain and platform health; and a **Geth StatefulSet** with snapshots and a documented DR path—ready for production SLOs. Helios/light clients are deliberately excluded from the production rollout.

---

# Monitoring / Alerting Documentation

This project uses the **kube-prometheus-stack** Helm chart to provide a complete, production-ready observability suite for the Ethereum node and related infrastructure.

### Why kube-prometheus-stack

* **Unified deployment** of Prometheus, Alertmanager, Grafana, and supporting CRDs in a single Helm release.
* **ServiceMonitor** and **PodMonitor** CRDs allow Kubernetes-native service scraping without manual Prometheus configuration changes.
* **Centralized monitoring** for both infrastructure and application metrics, deployable through GitOps workflows.
* **Prebuilt dashboards and alert rules** that can be customized to Ethereum-specific workloads.

### Grafana Access

* **Credentials**: Default admin username/password are defined in the Helm values file for local environments and are shown in the deployment summary.
* **URL**: The Grafana address will be displayed:

  * **Automatically at the end of `make all-local`**
  * Or at any time by running:

    ```bash
    make summary
    ```
* In local environments, Grafana is exposed via MetalLB + Ingress. In production, DNS and TLS should be provisioned via ExternalDNS and cert-manager.

### Dashboards

* The primary Ethereum node metrics view uses the **Go-Ethereum-by-Instance** dashboard — the official dashboard recommended by the Geth project — which provides detailed visibility into:

  * Peer counts and connection health
  * Sync progress and chain head metrics
  * Transaction pool size
  * RPC method latencies and error rates
  * Resource consumption (CPU, memory, disk I/O)
* This dashboard is automatically imported into Grafana as part of the deployment.
* The dashboard path and UID are shown in the deployment summary for direct navigation.

### Alerts

* Initial alerting rules are implemented via **kube-prometheus-stack CRDs** and stored under the `geth-node` Helm chart `templates/` directory.
* Current rules cover:

  * Peer count falling below a healthy threshold
  * Node sync lag exceeding expected limits
  * RPC error rate spikes
* In local environments, Alertmanager is preconfigured for basic testing.
  In production, it should be integrated with enterprise alerting backends (PagerDuty, Slack, Opsgenie, email, etc.).


With kube-prometheus-stack, this setup delivers centralized metrics collection, an industry-standard Geth-recommended dashboard (**Go-Ethereum-by-Instance**), and foundational alerting. All key monitoring endpoints, credentials, and dashboard links are surfaced automatically at the end of deployment or by running `make summary`.

---