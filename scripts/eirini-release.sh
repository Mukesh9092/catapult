#!/bin/bash
set -ex 

if [ "$KIND_VERSION" != "v0.4.0"]; then
 echo "We only support Kind version 0.4.0 for now"

 exit 1

fi
. scripts/include/common.sh

cat > eirini-values.yaml <<EOF
env:
  DOMAIN: &DOMAIN ${DOMAIN}
  # Uncomment if you want to use Diego to stage applications
  # ENABLE_OPI_STAGING: false
  UAA_HOST: uaa.${DOMAIN}
  UAA_PORT: 2793

kube:
  auth: rbac
  external_ips: &external_ips
  - ${container_ip}
  storage_class:
    persistent: persistent
    shared: persistent

secrets: &secrets
  CLUSTER_ADMIN_PASSWORD: ${CLUSTER_PASSWORD}
  UAA_ADMIN_CLIENT_SECRET: ${CLUSTER_PASSWORD}
  BLOBSTORE_PASSWORD: &BLOBSTORE_PASSWORD "${CLUSTER_PASSWORD}"

services: &services
  loadbalanced: false

eirini:
  env:
    DOMAIN: *DOMAIN
  services: *services
  opi:
    use_registry_ingress: false
    # Enable if use_registry_ingress is set to 'true'
    # ingress_endpoint: kubernetes-cluster-ingress-endpoint

  secrets:
    BLOBSTORE_PASSWORD: *BLOBSTORE_PASSWORD
    BITS_SERVICE_SECRET: &BITS_SERVICE_SECRET "${CLUSTER_PASSWORD}"
    BITS_SERVICE_SIGNING_USER_PASSWORD: &BITS_SERVICE_SIGNING_USER_PASSWORD  "${CLUSTER_PASSWORD}"

  kube:
    external_ips: *external_ips

bits:
  env:
    DOMAIN: *DOMAIN
  services: *services
  opi:
    use_registry_ingress: false
    # Enable if use_registry_ingress is set to 'true'
    # ingress_endpoint: kubernetes-cluster-ingress-endpoint

  secrets:
    BLOBSTORE_PASSWORD: *BLOBSTORE_PASSWORD
    BITS_SERVICE_SECRET: *BITS_SERVICE_SECRET
    BITS_SERVICE_SIGNING_USER_PASSWORD: *BITS_SERVICE_SIGNING_USER_PASSWORD

  kube:
    external_ips: *external_ips
EOF



helm repo add eirini https://cloudfoundry-incubator.github.io/eirini-release
helm repo add bits https://cloudfoundry-incubator.github.io/bits-service-release/helm
helm install eirini/uaa --namespace uaa --name uaa --values eirini-values.yaml
bash ../scripts/wait.sh uaa

SECRET=$(kubectl get pods --namespace uaa -o jsonpath='{.items[?(.metadata.name=="uaa-0")].spec.containers[?(.name=="uaa")].env[?(.name=="INTERNAL_CA_CERT")].valueFrom.secretKeyRef.name}')
CA_CERT="$(kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)"

cp -rfv ../config/config.toml ./config.toml

sed -i 's/http:\/\/localhost:32001/https:\/\/registry.'${DOMAIN}'/g' ./config.toml

# Overwrite config.toml with our own
docker cp config.toml ${cluster_name}-control-plane:/etc/containerd/config.toml

# Restart the kubelet
docker exec ${cluster_name}-control-plane systemctl restart kubelet.service

openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt -subj "/C=GB/ST=London/L=London/O=Global Security/OU=IT Department/CN=registry.${DOMAIN}"

helm install eirini/cf --namespace scf --name scf --values eirini-values.yaml --set "secrets.UAA_CA_CERT=${CA_CERT}" --set "eirini.secrets.BITS_TLS_KEY=$(cat domain.key)" --set "eirini.secrets.BITS_TLS_CRT=$(cat domain.crt)"

bash ../scripts/wait.sh scf