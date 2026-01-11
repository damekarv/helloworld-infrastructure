resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"
  timeout          = 600
  wait             = true

  values = [
    <<EOF
controller:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
EOF
  ]
}

resource "helm_release" "flagger" {
  name             = "flagger"
  repository       = "https://flagger.app"
  chart            = "flagger"
  namespace        = "flagger-system"
  create_namespace = true
  version          = "1.39.0"

  values = [
    <<EOF
metricsServer: "http://monitoring-prometheus-server.monitoring:80"
meshProvider: "nginx"
EOF
  ]
  
  depends_on = [helm_release.ingress_nginx]
}

resource "helm_release" "flagger_loadtester" {
  name       = "flagger-loadtester"
  repository = "https://flagger.app"
  chart      = "loadtester"
  namespace  = "flagger-system"
  version    = "0.28.0"

  depends_on = [helm_release.flagger]
}
