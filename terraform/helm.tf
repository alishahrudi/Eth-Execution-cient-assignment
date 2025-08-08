# Install Sealed Secrets
resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = "2.13.1"
  namespace  = "kube-system"

  set {
    name  = "fullnameOverride"
    value = "sealed-secrets-controller"
  }
}

resource "helm_release" "geth_node" {
  name       = "geth-node"
  chart      = var.geth_chart_path
  namespace  = kubernetes_namespace.geth.metadata[0].name
  depends_on = [helm_release.sealed_secrets]

  values = [
    file("${var.geth_chart_path}/values.local.yaml")
  ]
}

# Install Prometheus using your local chart
resource "helm_release" "prometheus" {
  name       = "prometheus"
  chart      = var.prometheus_chart_path
  namespace  = "monitoring"
  create_namespace = true

  values = [
    file("${var.prometheus_chart_path}/values.local.yaml")
  ]
}