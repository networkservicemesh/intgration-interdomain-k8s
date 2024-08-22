#!/bin/bash

K8S_VERSION=$(echo ${K8S_VERSION} | cut -d '.' -f 1,2 | cut -c 2-)
GKE_CLUSTER_VERSION=$(gcloud container get-server-config --zone="$GKE_CLUSTER_ZONE" --format=json \
    | jq '.channels[] | select (.channel=="REGULAR") | .validVersions[]' \
    | grep -m 1 "$K8S_VERSION" | tr -d '"')
if [ -z "$GKE_CLUSTER_VERSION" ]; then
    echo "GKE cluster version is not valid: $GKE_CLUSTER_VERSION"
    exit 1
fi

gcloud components install gke-gcloud-auth-plugin
gcloud components update
time gcloud container clusters create "${GKE_CLUSTER_NAME}" \
--project="${GKE_PROJECT_ID}" \
--machine-type="${GKE_CLUSTER_TYPE}" \
--num-nodes=1 \
--zone="${GKE_CLUSTER_ZONE}" \
--cluster-version="${GKE_CLUSTER_VERSION}" -q
echo "Writing config to ${KUBECONFIG}"
gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}" --project="${GKE_PROJECT_ID}" --zone="${GKE_CLUSTER_ZONE}"
kubectl create clusterrolebinding cluster-admin-binding  --clusterrole cluster-admin --user "$(gcloud config get-value account)"
git clone https://github.com/coredns/deployment.git
./deployment/kubernetes/deploy.sh | kubectl apply -f -
kubectl scale --replicas=0 deployment/kube-dns-autoscaler --namespace=kube-system
kubectl scale --replicas=0 deployment/kube-dns --namespace=kube-system
rm -rf deployment