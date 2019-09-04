#!/bin/bash
set -x

# duplicated in s/include/common.sh, needed for bootstrapping:
export CLUSTER_NAME=${CLUSTER_NAME:-kind}
export BUILD_DIR=build${CLUSTER_NAME}

mkdir "$BUILD_DIR"

. scripts/include/common.sh

if [[ "$OSTYPE" == "darwin"* ]]; then 
  export KIND_OS_TYPE="${KIND_OS_TYPE:-kind-darwin-amd64}" 
else 
  export KIND_OS_TYPE="${KIND_OS_TYPE:-kind-linux-amd64}" 
fi

if [ -z "$EKCP_HOST" ]; then
    wget https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/${KIND_OS_TYPE}
    mv kind-linux-amd64 kind
    chmod +x kind
fi

cat <<HEREDOC > .envrc
export KUBECONFIG=$(pwd)/kubeconfig
export HELM_HOME=$(pwd)/.helm
export CF_HOME=$(pwd)/.cf
HEREDOC

popd
