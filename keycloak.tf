variable "keycloak_admin_password" {
  description = "Bootstrap password for the Keycloak admin user."
  type        = string
  sensitive   = true
}

resource "kubernetes_namespace_v1" "keycloak" {
  metadata {
    name = "keycloak"
    labels = {
      "traefik-gateway-access" = "true"
    }
  }
}

resource "kubernetes_secret_v1" "keycloak_admin" {
  metadata {
    name      = "keycloak-admin"
    namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
  }

  data = {
    "admin-password" = var.keycloak_admin_password
  }

  depends_on = [helm_release.traefik]
}

resource "kubectl_manifest" "nginx_gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "keycloak-gateway"
      namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
    }
    spec = {
      gatewayClassName = "traefik"
      listeners = [{
        name          = "http"
        protocol      = "HTTP"
        port          = 8000
        allowedRoutes = { namespaces = { from = "Same" } }
        },
        {
          name          = "https"
          protocol      = "HTTPS"
          port          = 8443
          allowedRoutes = { namespaces = { from = "Same" } }
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              name      = "secret-tls"
              namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
            }]
          }
      }]
    }
  })

  depends_on = [helm_release.traefik]
}

resource "helm_release" "keycloak" {
  name             = "keycloak"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "keycloak"
  version          = "25.2.0"
  namespace        = kubernetes_namespace_v1.keycloak.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 600
  upgrade_install  = true

  values = [
    yamlencode({
      fullnameOverride = "keycloak"
      global = {
        security = {
          allowInsecureImages = true
        }
      }
      image = {
        repository = "bitnamilegacy/keycloak"
      }
      auth = {
        adminUser         = "admin"
        existingSecret    = kubernetes_secret_v1.keycloak_admin.metadata[0].name
        passwordSecretKey = "admin-password"
      }
      httpEnabled  = true
      proxyHeaders = "xforwarded"
      extraEnvVars = [{
        name  = "KC_HOSTNAME"
        value = "keycloak.example.com"
      }]
      postgresql = {
        image = {
          repository = "bitnamilegacy/postgresql"
        }
        primary = {
          persistence = {
            enabled = false
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_secret_v1.keycloak_admin]
}

resource "kubectl_manifest" "keycloak_route" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "keycloak-route"
      namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
    }
    spec = {
      parentRefs = [{
        name        = "keycloak-gateway"
        sectionName = "http"
        },
        {
          name        = "keycloak-gateway"
          sectionName = "https"
      }]
      hostnames = ["keycloak.example.com"]
      rules = [{
        backendRefs = [{
          name = "keycloak"
          port = 80
        }]
      }]
    }
  })

  depends_on = [
    helm_release.keycloak,
    helm_release.traefik,
  ]
}