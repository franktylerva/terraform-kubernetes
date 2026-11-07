resource "kubernetes_deployment_v1" "nginx" {
  depends_on = [terraform_data.gateway_api_crds]
  metadata {
    name = "scalable-nginx-example"
    labels = {
      App = "ScalableNginxExample"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "ScalableNginxExample"
      }
    }
    template {
      metadata {
        labels = {
          App = "ScalableNginxExample"
        }
      }
      spec {
        container {
          image = "nginx:stable-alpine-slim"
          name  = "example"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "nginx" {
  depends_on = [terraform_data.gateway_api_crds]
  metadata {
    name = "nginx-example"
  }
  spec {
    selector = {
      App = kubernetes_deployment_v1.nginx.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "kubectl_manifest" "nginx_gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "nginx-gateway"
      namespace = "default"
    }
    spec = {
      gatewayClassName = "traefik"
      listeners = [{
        name          = "http"
        protocol      = "HTTP"
        port          = 8000
        allowedRoutes = { namespaces = { from = "Same" } }
      }]
    }
  })

  depends_on = [helm_release.traefik]
}

resource "kubectl_manifest" "nginx_route" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "nginx-route"
      namespace = "default"
    }
    spec = {
      parentRefs = [{
        name        = kubectl_manifest.nginx_gateway.name
        sectionName = "http"
      }]
      hostnames = ["example-nginx.com"]
      rules = [{
        # matches = [{
        #   path = {
        #     type  = "PathPrefix"
        #     value = "/"
        #   }
        # }]
        backendRefs = [{
          name = kubernetes_service_v1.nginx.metadata[0].name
          port = 80
        }]
      }]
    }
  })
}