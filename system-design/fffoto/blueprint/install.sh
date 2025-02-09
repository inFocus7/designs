#!/bin/bash

set -e

relative_dir=$(dirname "$0")

cluster_name="fffoto-blueprint"

# go through flags, if `-c/--clean` is passed, delete the cluster
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -c|--clean) kind delete cluster --name "${cluster_name}"; exit ;;
    *) echo "[ERR] Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

# Ensure proper setup exists for a local deployment.
echo """FFFOTO SYSTEM DESIGN BLUEPRINT

This installs a 'blueprint' of the system design for fffoto.
This script is intended to be run on a local machine, not a cloud provider."""

INFO_COLOR="\033[0;34m"
ERR_COLOR="\033[0;31m"
WARN_COLOR="\033[0;33m"
RESET_COLOR="\033[0m"

log_info() {
    echo "${INFO_COLOR}[INFO] $1${RESET_COLOR}"
}

log_warn() {
    echo "${WARN_COLOR}[WARN] $1${RESET_COLOR}"
}

log_err() {
    echo "${ERR_COLOR}[ERR] $1${RESET_COLOR}"
}


required_commands=("kind" "kubectl" "helm" "docker" "cloud-provider-kind" "istioctl" "yq")

missing_commands=()
for command in "${required_commands[@]}"; do
  if ! command -v "${command}" &> /dev/null; then
    missing_commands+=("${command}")
  fi
done

if [ ${#missing_commands[@]} -ne 0 ]; then
  log_err "Missing commands: ${missing_commands[@]}"
  exit 1
else
  log_info "All required commands found."
fi

# the versions are in the format of "command:flag:expected_version"
command_versions=(
  "kind:version:0.26.0"
  "kubectl:version --client -o yaml | yq .clientVersion.gitVersion:1.32.1"
  "helm:version --template='{{.Version}}':3.17.0"
  "docker:version -f json | jq '.[\"Client\"].Version':24.0.7"
  "istioctl:version -o yaml | yq .clientVersion.version:1.24.2"
)
for command_version in "${command_versions[@]}"; do
  command=$(echo "${command_version}" | cut -d':' -f1)
  flag=$(echo "${command_version}" | cut -d':' -f2)
  expected_version=$(echo "${command_version}" | cut -d':' -f3)

  # strip any backslashes from backslash-double quotes in the flag
  flag=$(echo "${flag}" | sed 's/\\//g')

  # find the version within the printed output of the command
  version=$(eval "${command} ${flag}")
  if [[ ! "${version}" == *"${expected_version}"* ]]; then
    log_warn "${command} version mismatch. Expected: ${expected_version}, Found: ${version}"
  fi
done

# check that the user has istio helm repo added can do `helm repo list -o yaml | yq '.[].name'` which returns the list of repos, then search for name: istio
if ! helm repo list -o yaml | yq '.[].name' | grep -q "istio"; then
  log_err "Istio helm repo not found. Please add it: https://istio.io/latest/docs/setup/install/helm/"
  exit 1
fi

kind_version="v1.30.0"

log_info "Setting up ${cluster_name} cluster..."

kind create cluster \
  --name "${cluster_name}" \
  --image "kindest/node:${kind_version}" \
  --config="${relative_dir}/assets/cluster-config.yaml"

kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"

log_info "Installing Istio into the cluster..."

istioctl install -f "${relative_dir}/assets/istio-profile.yaml"

kubectl apply -f "${relative_dir}/assets/ingress-gateway.yaml"

log_info "Setting up the Account workload..."

kubectl create ns account
kubectl label ns account istio-injection=enabled

kubectl apply -f "${relative_dir}/assets/account/account-workload.yaml"
kubectl wait --for=condition=ready pod -l app=account -n account

kubectl apply -f "${relative_dir}/assets/account/account-routing.yaml"
kubectl apply -f "${relative_dir}/assets/account/account-security.yaml"

log_info "Setting up the Group workload..."

kubectl create ns group
kubectl label ns group istio-injection=enabled

kubectl apply -f "${relative_dir}/assets/group/group-workload.yaml"
kubectl wait --for=condition=ready pod -l app=group -n group

kubectl apply -f "${relative_dir}/assets/group/group-routing.yaml"
kubectl apply -f "${relative_dir}/assets/group/group-security.yaml"

log_info "Setting up the Post workload..."

kubectl create ns post
kubectl label ns post istio-injection=enabled

kubectl apply -f "${relative_dir}/assets/post/post-workload.yaml"
kubectl wait --for=condition=ready pod -l app=post -n post

kubectl apply -f "${relative_dir}/assets/post/post-routing.yaml"
kubectl apply -f "${relative_dir}/assets/post/post-security.yaml"

log_info "Setting up the MediaProccessor workload..."

kubectl create ns media-processor
kubectl label ns media-processor istio-injection=enabled

kubectl apply -f "${relative_dir}/assets/media-processor/media-processor-workload.yaml"
kubectl wait --for=condition=ready pod -l app=media-processor -n media-processor

kubectl apply -f "${relative_dir}/assets/media-processor/media-processor-routing.yaml"
kubectl apply -f "${relative_dir}/assets/media-processor/media-processor-security.yaml"

# TODO/NOTE: The routes and security stuff created for the services above do not have egresses (Sidecars) to the databases as i'm still figuring out their setup.

# TODO: Set up RedisDB and Istio setups

# TODO: Set up the Database (probably Postgresql + pgAdmin, alongside Cassandra?) and Istio setups

# TODO: Set up Kratos and Ory Hydra and Istio setups

# TODO: Set up S3 connection and Istio setups

# TODO: Run the cloud-provider-kind so there are external IPs for the services
# TODO: Get gateway's external IP to access through that endpoint, once/if routes are set up.
# TODO: mTLS security and PeerAuth for the services?

log_info "Done setting up the blueprint of the system design for fffoto."

echo """
To set up observability and view the connections you can apply the istio samples/addons/{prometheus,grafana,kiali}.yaml files.
You can run cloud-provider-kind to have an External IP for the gateway, then access it through:
export GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
"""