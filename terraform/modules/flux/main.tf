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

resource "kubectl_manifest" "cluster_secret_store" {
  count = var.cluster_secret_store.enabled ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1
    kind: ClusterSecretStore
    metadata:
      name: ${var.cluster_secret_store.name}
    spec:
      provider:
        aws:
          service: SecretsManager
          region: ${var.region}
          auth:
            jwt:
              serviceAccountRef:
                name: external-secrets
                namespace: external-secrets
  YAML

  depends_on = [helm_release.flux2]
}

resource "kubectl_manifest" "ghcr_secret" {
  count = var.ghcr_secret.enabled ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1
    kind: ExternalSecret
    metadata:
      name: ${var.ghcr_secret.name}
      namespace: flux-system
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: ${var.cluster_secret_store.name}
        kind: ClusterSecretStore
      target:
        name: ${var.ghcr_secret.name}
        creationPolicy: Owner
      data:
        - secretKey: username
          remoteRef:
            key: ${var.ghcr_secret.secret_name}
            property: username
        - secretKey: password
          remoteRef:
            key: ${var.ghcr_secret.secret_name}
            property: password
  YAML

  depends_on = [kubectl_manifest.cluster_secret_store]
}

resource "kubectl_manifest" "app_ghcr_secret" {
  count = var.app_ghcr_secret.enabled ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1
    kind: ExternalSecret
    metadata:
      name: ${var.app_ghcr_secret.name}
      namespace: ${var.app_ghcr_secret.namespace}
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: ${var.cluster_secret_store.name}
        kind: ClusterSecretStore
      target:
        name: ${var.app_ghcr_secret.name}
        creationPolicy: Owner
        template:
          type: kubernetes.io/dockerconfigjson
          data:
            .dockerconfigjson: '{"auths":{"ghcr.io":{"username":"{{ .username }}","password":"{{ .password }}","auth":"{{ printf "%s:%s" .username .password | b64enc }}"}}}'
      data:
        - secretKey: username
          remoteRef:
            key: ${var.app_ghcr_secret.secret_name}
            property: username
        - secretKey: password
          remoteRef:
            key: ${var.app_ghcr_secret.secret_name}
            property: password
  YAML

  depends_on = [kubectl_manifest.cluster_secret_store]
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
