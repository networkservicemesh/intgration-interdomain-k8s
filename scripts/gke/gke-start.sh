#!/bin/bash

gcloud components install gke-gcloud-auth-plugin
gcloud components update
time gcloud container clusters create "${GKE_CLUSTER_NAME}" --project="${GKE_PROJECT_ID}" --machine-type="${GKE_CLUSTER_TYPE}" --num-nodes=1 --zone="${GKE_CLUSTER_ZONE}" -q
echo "Writing config to ${KUBECONFIG}"
gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}" --project="${GKE_PROJECT_ID}" --zone="${GKE_CLUSTER_ZONE}"
kubectl create clusterrolebinding cluster-admin-binding  --clusterrole cluster-admin --user "$(gcloud config get-value account)"
git clone https://github.com/coredns/deployment.git
./deployment/kubernetes/deploy.sh | kubectl apply -f -
kubectl scale --replicas=0 deployment/kube-dns-autoscaler --namespace=kube-system
kubectl scale --replicas=0 deployment/kube-dns --namespace=kube-system
rm -rf deployment