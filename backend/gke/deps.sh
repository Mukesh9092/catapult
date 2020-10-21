#!/usr/bin/env bash

. ../../include/common.sh
[[ -d "${BUILD_DIR}" ]] || exit 0
. .envrc

if [[ "$DOWNLOAD_CATAPULT_DEPS" == "false" ]]; then
    ok "Skipping downloading GKE deps, using host binaries"
    exit 0
fi

gcloudpath=bin/gcloud
if [ ! -e "$gcloudpath" ]; then
    curl -o google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-264.0.0-linux-x86_64.tar.gz
    tar -xf google-cloud-sdk.tar.gz
    rm google-cloud-sdk.tar.gz
    pushd google-cloud-sdk || exit
    bash ./install.sh -q
    popd || exit
    echo "source $(pwd)/google-cloud-sdk/path.bash.inc" >> .envrc
fi

terraformpath=bin/terraform
if [ ! -e "$terraformpath" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        curl -o terraform.zip https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_darwin_amd64.zip
    else
        curl -o terraform.zip https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_linux_amd64.zip
    fi
    unzip terraform.zip && rm -rf terraform.zip
    chmod +x terraform && mv terraform bin/
fi
