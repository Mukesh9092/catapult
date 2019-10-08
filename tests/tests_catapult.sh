#!/bin/bash

ROOT_DIR="$(git rev-parse --show-toplevel)"

[ ! -d "shunit2" ] && git clone https://github.com/kward/shunit2.git

setUp() {
    export CLUSTER_NAME=test
    export ROOT_DIR="$(git rev-parse --show-toplevel)"
    pushd "$ROOT_DIR"
}

tearDown() {
    export ROOT_DIR="$(git rev-parse --show-toplevel)"
    pushd "$ROOT_DIR"
    rm -rf buildtest
}

# Tests creation and deletion of build directory
testBuilddir() {
  rm -rf buildtest
  make buildir
  assertTrue 'create buildir' "[ -d 'buildtest' ]"
  ENVRC="$(cat "$PWD"/buildtest/.envrc)"
  assertContains 'contains KUBECONFIG' "$ENVRC" 'KUBECONFIG="$(pwd)"/kubeconfig'
  assertContains 'contains CLUSTER_NAME' "$ENVRC" 'CLUSTER_NAME=test'
  assertContains 'contains CF_HOME' "$ENVRC" 'CF_HOME="$(pwd)"'
  make clean
  assertTrue 'clean buildir' "[ ! -d 'buildtest' ]"
}

# Tests values generation
testConfig() {
  rm -rf buildtest
  make buildir
  DEFAULT_STACK=sle CLUSTER_PASSWORD=test123 make -C scripts/scf gen-config
  assertTrue 'create buildir' "[ -d $ROOT_DIR/buildtest ]"
  assertTrue 'create config values' "[ -e $ROOT_DIR/buildtest/scf-config-values.yaml ]"

  VALUES_FILE="$(cat $ROOT_DIR/buildtest/scf-config-values.yaml)"
  assertContains 'generates correctly CLUSTER_ADMIN_PASSWORD' "$VALUES_FILE" "CLUSTER_ADMIN_PASSWORD: test123"
  assertContains 'generates correctly KUBE_CSR_AUTO_APPROVAL' "$VALUES_FILE" "KUBE_CSR_AUTO_APPROVAL: true"
  assertContains 'generates correctly DEFAULT_STACK' "$VALUES_FILE" "DEFAULT_STACK: \"sle\""
  assertContains 'generates correctly GARDEN_ROOTFS_DRIVER' "$VALUES_FILE" "GARDEN_ROOTFS_DRIVER: \"btrfs\""
}

# Load shUnit2.
. ./shunit2/shunit2
