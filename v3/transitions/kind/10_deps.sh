#!/bin/bash

. ./defaults.sh
. ../../include/common.sh
. .envrc

if [[ "$DOWNLOAD_CATAPULT_DEPS" == "false" ]]; then
    ok "Skipping downloading kind deps, using host binaries"
    exit 0
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  export KIND_OS_TYPE="${KIND_OS_TYPE:-kind-darwin-amd64}"
else
  export KIND_OS_TYPE="${KIND_OS_TYPE:-kind-linux-amd64}"
fi

# needed by kind
sudo -n /sbin/modprobe br_netfilter  || :

kindpath=bin/kind
if [ ! -e "$kindpath" ]; then
    if [[ $KIND_VERSION =~ ^0\.2\.[0-9]$ ]]; then
        curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/${KIND_OS_TYPE}
    else
        curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/${KIND_OS_TYPE}
    fi
    chmod +x kind && mv kind $kindpath
fi

popd || exit

ok "Deps correctly downloaded"
