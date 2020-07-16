#!/bin/bash

. ../../include/common.sh
. .envrc

info "Generating stratos config values from scf values"

cp scf-config-values.yaml scf-config-values-for-stratos.yaml
for patch in "$ROOT_DIR"/modules/stratos/patches/*.yaml; do
    selective-merge -d kubecf=scf-config-values-for-stratos.yaml \
                    -p "$patch" \
                    > scf-config-values-for-stratos_temp.yaml
    mv scf-config-values-for-stratos_temp.yaml scf-config-values-for-stratos.yaml
done

ok "Stratos config values generated"
