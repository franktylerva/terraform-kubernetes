resource "kubernetes_storage_class_v1" "registry" {
  metadata {
    name = "registry-local"
  }

  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = "Immediate"
}

resource "kubernetes_persistent_volume_v1" "registry" {
  metadata {
    name = "registry-data"
  }

  spec {
    capacity = {
      storage = "5Gi"
    }

    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class_v1.registry.metadata[0].name

    persistent_volume_source {
      host_path {
        path = "/var/lib/registry"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "registry" {
  metadata {
    name = "registry-data"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class_v1.registry.metadata[0].name

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_v1.registry,
    kubernetes_storage_class_v1.registry,
  ]
}

resource "kubernetes_deployment_v1" "registry" {
  metadata {
    name = "registry"
    labels = {
      app = "registry"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "registry"
      }
    }

    template {
      metadata {
        labels = {
          app = "registry"
        }
      }

      spec {
        container {
          name  = "registry"
          image = "registry:2"

          port {
            name           = "http"
            container_port = 5000
          }

          volume_mount {
            name       = "registry-data"
            mount_path = "/var/lib/registry"
          }
        }

        volume {
          name = "registry-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.registry.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "registry" {
  metadata {
    name = "registry"
  }

  spec {
    selector = {
      app = kubernetes_deployment_v1.registry.spec[0].template[0].metadata[0].labels.app
    }

    port {
      name        = "http"
      port        = 5000
      target_port = 5000
    }
  }
}

resource "kubectl_manifest" "registry_route" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "registry-route"
      namespace = "default"
    }
    spec = {
      parentRefs = [
        {
          name        = "nginx-gateway"
          sectionName = "http"
        },
        {
          name        = "nginx-gateway"
          sectionName = "https"
        }
      ]
      hostnames = ["registry.example.com"]
      rules = [{
        backendRefs = [{
          name = kubernetes_service_v1.registry.metadata[0].name
          port = 5000
        }]
      }]
    }
  })

  depends_on = [kubectl_manifest.nginx_gateway]
}