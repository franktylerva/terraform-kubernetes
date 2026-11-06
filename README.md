# Kubernetes provider with OpenTofu and kind

This tutorial uses OpenTofu's Kubernetes provider to deploy an NGINX
Deployment and NodePort Service to a local Kubernetes cluster created with
kind. The provider reads the active context and credentials from your local
`kubectl` kubeconfig (`~/.kube/config`), so cluster connection details do not
need to be copied into Terraform variables.

## Prerequisites

- **OpenTofu** — install with Homebrew on macOS:

  ```sh
  brew install opentofu
  ```

  For other operating systems, follow the
  [OpenTofu installation guide](https://opentofu.org/docs/intro/install/).

- **kind** — install with Homebrew on macOS:

  ```sh
  brew install kind
  ```

  See the [kind installation guide](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
  for other platforms.

- **kubectl** — install using the
  [Kubernetes instructions](https://kubernetes.io/docs/tasks/tools/).
- **A container runtime** supported by kind, such as Docker. On macOS, install
  and start Docker Desktop before creating the cluster.

Verify the tools are available:

```sh
tofu version
kind version
kubectl version --client
docker info
```

## Create the local cluster

From this directory, create a kind cluster using the included configuration:

```sh
kind create cluster --name tofu-k8s --config kind-config.yaml
```

The configuration maps host port `30201` to the kind node's port `30201`, which
lets the NodePort Service in this example be reached at `http://localhost:30201`.
kind writes cluster access details to `~/.kube/config`. Confirm that kubectl is
using the new cluster:

```sh
kubectl config use-context kind-tofu-k8s
kubectl cluster-info
```

The Kubernetes provider is configured to read `~/.kube/config` and use its
current context. If you have other Kubernetes contexts, check the active
context before applying changes.

## Deploy the example

Initialize OpenTofu, review the proposed changes, then apply them:

```sh
tofu init
tofu plan
tofu apply
```

Confirm the Deployment and Service are ready:

```sh
kubectl get deployments,services
curl http://localhost:30201
```

The example creates four NGINX replicas. The Service exposes them through the
NodePort configured in `kubernetes.tf`.

## Clean up

Remove the Terraform-managed resources before deleting the cluster:

```sh
tofu destroy
kind delete cluster --name tofu-k8s
```

## Credentials and state

This configuration uses your local kubeconfig rather than storing cluster
certificates or keys in `.tfvars` files. Keep your kubeconfig and Terraform
state files private, and do not commit credentials or state to source control.
