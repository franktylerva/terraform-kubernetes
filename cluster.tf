resource "kind_cluster" "default" {
  name           = "terraform-learn"
  wait_for_ready = true
}

locals {
  gateway_api_version = "v1.7.0"
}

resource "terraform_data" "gateway_api_crds" {
  triggers_replace = [
    kind_cluster.default.id,
    local.gateway_api_version,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${local.gateway_api_version}/standard-install.yaml
      # kubectl wait --for=condition=Established --timeout=60s crd -l customresourcedefinition.apiextensions.k8s.io/gateways.gateway.networking.k8s.io/bundle-version=${local.gateway_api_version},gateway.networking.k8s.io/channel=standard
    EOT

    environment = {
      KUBECONFIG = kind_cluster.default.kubeconfig_path
    }
  }
}