#!/usr/bin/env bash

. ../../include/common.sh
. .envrc


minikube stop --profile "$CLUSTER_NAME"
