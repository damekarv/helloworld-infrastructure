################################################################################
# Flux CD
################################################################################
resource "helm_release" "flux2" {
  name       = "flux2"
  # repository = "oci://ghcr.io/fluxcd-community/charts"
  chart      = "${path.module}/charts/flux2"
  version    = "2.13.0"
  namespace        = "flux-system"
  create_namespace = true
}

resource "kubectl_manifest" "git_repositories" {
  for_each = var.repositories

  yaml_body = <<-YAML
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: ${each.key}
      namespace: flux-system
    spec:
      interval: ${each.value.interval}
      url: ${each.value.url}
      ref:
        branch: ${each.value.branch}
      %{ if each.value.secret_name != null }
      secretRef:
        name: ${each.value.secret_name}
      %{ endif }
  YAML

  depends_on = [helm_release.flux2]
}

resource "kubectl_manifest" "kustomizations" {
  for_each = var.repositories

  yaml_body = <<-YAML
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
      name: ${each.key}
      namespace: flux-system
    spec:
      interval: ${each.value.interval}
      path: ${each.value.path}
      prune: true
      wait: true
      sourceRef:
        kind: GitRepository
        name: ${each.key}
  YAML

  depends_on = [kubectl_manifest.git_repositories]
}
