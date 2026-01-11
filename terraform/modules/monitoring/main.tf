resource "helm_release" "kube_prometheus_stack" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "60.0.0"

  values = [
    <<EOF
prometheus:
  prometheusSpec:
    retention: 24h
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 1Gi
grafana:
  enabled: true
  adminPassword: "admin"
alertmanager:
  enabled: false
EOF
  ]
}
