#!/bin/bash

. ./defaults.sh
. ../../include/common.sh
. .envrc

. "$ROOT_DIR"/modules/kubecf/workarounds/pre-upgrade-cap-2.1.0-rc2.sh

info "Upgrading CFO…"
helm list -A

helm_upgrade cf-operator cf-operator/ \
             --namespace cf-operator \
             --set "global.singleNamespace.name=scf"

info "Wait for cf-operator to be ready"

wait_for_cf-operator

ok "cf-operator ready"
helm list -A

info "Upgrading KubeCF…"
helm list -A

if [ -n "$SCF_CHART" ]; then
# save SCF_CHART on cap-values configmap
    kubectl patch -n kube-system configmap cap-values -p $'data:\n chart: "'$SCF_CHART'"'
fi

helm_upgrade susecf-scf kubecf/ \
             --namespace scf \
             --values scf-config-values.yaml
sleep 10

wait_ns scf

ok "KubeCF deployment upgraded successfully"
helm list -A
