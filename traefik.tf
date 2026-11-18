resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "41.1.0"
  namespace        = "traefik"
  create_namespace = true
  wait             = true
  timeout          = 300
  upgrade_install  = true

  values = [
    yamlencode({
      providers = {
        kubernetesGateway = {
          enabled = true
        }
      }
      gateway = {
        enabled = true
        listeners = {
          web = {
            namespacePolicy = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "traefik-gateway-access" = "true"
                }
              }
            }
          }
        }
      }
      gatewayClass = { enabled = true }
      service      = { spec = { type = "NodePort" } }
    })
  ]

  depends_on = [terraform_data.gateway_api_crds]
}