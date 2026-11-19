resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "oci://quay.io/jetstack/charts"
  chart            = "cert-manager"
  version          = "v1.21.3"
  namespace        = "cert-manager"
  create_namespace = false
  wait             = true
  timeout          = 600
  upgrade_install  = true

  values = [
    yamlencode({
      crds = {
        enabled = true
      }
      config = {
        enableGatewayAPI = true
      }
    })
  ]
}

resource "kubectl_manifest" "cert_manager_issuer" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "mkcert-issuer"
    }
    spec = {
      ca = {
        secretName = "mkcert-ca-key-pair"
      }
    }
  })

  depends_on = [helm_release.cert_manager]
}