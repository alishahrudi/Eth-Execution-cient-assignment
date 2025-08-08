Based on your project structure and the Terraform implementation I provided, here's the cloud architecture diagram for deploying your Geth node on GCP:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GCP PROJECT                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        VPC NETWORK (geth-vpc)                       │    │
│  │  ┌──────────────────────────────────────────────────────────────┐   │    │
│  │  │                 SUBNET (geth-subnet)                         │   │    │
│  │  │                 10.0.0.0/20                                  │   │    │
│  │  └──────────────────────────────────────────────────────────────┘   │    │
│  │                                                                     │    │
│  │  ┌──────────────────────────────────────────────────────────────┐   │    │
│  │  │              FIREWALL RULES                                  │   │    │
│  │  │  • allow-internal: Internal traffic                          │   │    │
│  │  │  • allow-geth-p2p: Geth P2P ports (30303 TCP/UDP)           │   │    │
│  │  └──────────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    GKE CLUSTER (geth-cluster)                       │    │
│  │  ┌──────────────────────────────────────────────────────────────┐   │    │
│  │  │                 NODE POOL (geth-node-pool)                   │   │    │
│  │  │                 • Machine Type: n1-standard-8               │   │    │
│  │  │                 • Auto-scaling: 2-5 nodes                    │   │    │
│  │  │                 • Tags: geth-node                            │   │    │
│  │  └──────────────────────────────────────────────────────────────┘   │    │
│  │                                                                     │    │
│  │  ┌──────────────────────────────────────────────────────────────┐   │    │
│  │  │                    KUBERNETES RESOURCES                      │   │    │
│  │  │  ┌────────────────────────────────────────────────────────┐  │   │    │
│  │  │  │  NAMESPACE: geth                                       │  │   │    │
│  │  │  │  ┌──────────────────────────────────────────────────┐  │  │   │    │
│  │  │  │  │  STATEFULSET: geth-node                          │  │  │   │    │
│  │  │  │  │  • Uses your local geth-node Helm chart          │  │  │   │    │
│  │  │  │  │  • Single replica                                │  │  │   │    │
│  │  │  │  │  • 5TB persistent storage                        │  │  │   │    │
│  │  │  │  └──────────────────────────────────────────────────┘  │  │   │    │
│  │  │  │  ┌──────────────────────────────────────────────────┐  │  │   │    │
│  │  │  │  │  SERVICE: geth-node (LoadBalancer)               │  │  │   │    │
│  │  │  │  │  • External IP assigned by GCP                   │  │  │   │    │
│  │  │  │  │  • Ports: 8545, 8546, 30303                      │  │  │   │    │
│  │  │  │  └──────────────────────────────────────────────────┘  │  │   │    │
│  │  │  │  ┌──────────────────────────────────────────────────┐  │  │   │    │
│  │  │  │  │  CRONJOB: geth-backup                            │  │  │   │    │
│  │  │  │  │  • Daily backups at 2 AM                         │  │  │   │    │
│  │  │  │  │  • Stores in Cloud Storage                       │  │  │   │    │
│  │  │  │  └──────────────────────────────────────────────────┘  │  │   │    │
│  │  │  └────────────────────────────────────────────────────────┘  │   │    │
│  │  │  ┌────────────────────────────────────────────────────────┐  │   │    │
│  │  │  │  NAMESPACE: monitoring                               │  │   │    │
│  │  │  │  • Prometheus monitoring stack                       │  │   │    │
│  │  │  │  • Uses your local kube-prometheus-stack chart       │  │   │    │
│  │  │  └────────────────────────────────────────────────────────┘  │   │    │
│  │  │  ┌────────────────────────────────────────────────────────┐  │   │    │
│  │  │  │  NAMESPACE: kube-system                              │  │   │    │
│  │  │  │  • Sealed Secrets controller                         │  │   │    │
│  │  │  └────────────────────────────────────────────────────────┘  │   │    │
│  │  └──────────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                   CLOUD STORAGE (Backup Bucket)                     │    │
│  │  • Name: geth-backups-your-project                              │    │
│  │  • Encrypted with KMS                                           │    │
│  │  • 30-day retention policy                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        KMS (Key Management)                         │    │
│  │  • Key Ring: geth-backup-keyring                                │    │
│  │  • Crypto Key: geth-backup-key                                  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        IAM & SECURITY                               │    │
│  │  • Service Account: gke-node-sa                                 │    │
│  │  • Roles:                                                        │    │
│  │    - roles/logging.logWriter                                    │    │
│  │    - roles/monitoring.metricWriter                              │    │
│  │    - roles/storage.objectAdmin                                  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Components:

1. **Networking Layer**: VPC with dedicated subnet and firewall rules
2. **Compute Layer**: GKE cluster with auto-scaling node pool
3. **Storage Layer**: 5TB SSD persistent disk for Geth data
4. **Application Layer**: Geth node deployed as StatefulSet with LoadBalancer service
5. **Monitoring**: Prometheus/Grafana stack for monitoring and alerting
6. **Security**: Sealed Secrets for managing sensitive data
7. **Backup**: Automated daily backups to encrypted Cloud Storage
8. **Access Control**: Dedicated service accounts with least-privilege permissions

This architecture provides a production-ready, scalable, and secure deployment of your Ethereum node on GCP with proper backup and monitoring capabilities.