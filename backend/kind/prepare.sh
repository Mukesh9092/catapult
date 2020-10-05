#!/bin/bash

. ../../include/common.sh
. .envrc

kubectl create clusterrolebinding admin --clusterrole=cluster-admin --user=system:serviceaccount:kube-system:default
kubectl create clusterrolebinding uaaadmin --clusterrole=cluster-admin --user=system:serviceaccount:uaa:default
kubectl create clusterrolebinding scfadmin --clusterrole=cluster-admin --user=system:serviceaccount:scf:default

# Trust the kubernetes ca on the node so CF application containers can be pulled
# from the registry (otherwise it fails because the ca is not trusted).
info "Trusting the Kubernetes certificate on nodes"
docker exec -it "${CLUSTER_NAME}-control-plane" bash -c 'cp /etc/kubernetes/pki/ca.crt /etc/ssl/certs/ && update-ca-certificates && (systemctl list-units | grep containerd > /dev/null && systemctl restart containerd)'

cat > storageclass.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hostpath-provisioner
  namespace: kube-system
---

kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: hostpath-provisioner
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["list", "watch", "create", "update", "patch"]
---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: hostpath-provisioner
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: hostpath-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: hostpath-provisioner
  apiGroup: rbac.authorization.k8s.io
---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: Role
metadata:
  name: hostpath-provisioner
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "get", "delete"]
---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: hostpath-provisioner
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: hostpath-provisioner
subjects:
- kind: ServiceAccount
  name: hostpath-provisioner
---

# -- Create a pod in the kube-system namespace to run the host path provisioner
apiVersion: v1
kind: Pod
metadata:
  namespace: kube-system
  name: hostpath-provisioner
spec:
  serviceAccountName: hostpath-provisioner
  containers:
    - name: hostpath-provisioner
      image: mazdermind/hostpath-provisioner:latest
      imagePullPolicy: "IfNotPresent"
      env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: PV_DIR
          value: /mnt/kubernetes-pv-manual

      volumeMounts:
        - name: pv-volume
          mountPath: /mnt/kubernetes-pv-manual
  volumes:
    - name: pv-volume
      hostPath:
        path: /mnt/kubernetes-pv-manual
---

# -- Create the standard storage class for running on-node hostpath storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  namespace: kube-system
  name: persistent
  annotations:
    storageclass.beta.kubernetes.io/is-default-class: "true"
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: EnsureExists
provisioner: hostpath
EOF

kubectl delete storageclass standard
kubectl create -f ../kube/storageclass.yaml

helm_init_client

container_id=$(docker ps -f "name=${CLUSTER_NAME}-control-plane" -q)
container_ip=$(docker inspect $container_id | jq -r .[0].NetworkSettings.Networks.bridge.IPAddress)
domain="${container_ip}.$MAGICDNS"

if ! kubectl get configmap -n kube-system 2>/dev/null | grep -qi cap-values; then
    kubectl create configmap -n kube-system cap-values \
            --from-literal=public-ip="${container_ip}" \
            --from-literal=services="hardcoded" \
            --from-literal=domain="$domain" \
            --from-literal=platform="kind"
fi

# Wait for default SA to be ready:
# https://github.com/kubernetes/kubernetes/issues/66689#issuecomment-463097073
info "Wait for default SA to be ready"
n=0; until ((n >= 60)); do kubectl -n default get serviceaccount default -o name && break; n=$((n + 1)); sleep 1; done; ((n < 60))
ok "Cluster prepared"
