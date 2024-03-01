#!/bin/bash

echo "aws region is $AWS_REGION"

export IAM_NAME=ebs-csi-controller-sa

apt-get update && apt-get -y install curl dnsutils

curl -LO https://storage.googleapis.com/kubernetes-release/release/"${AWS_K8S_VERSION}"/bin/linux/amd64/kubectl
chmod +x kubectl
mkdir -p ~/.local/bin
mv ./kubectl ~/.local/bin/kubectl


curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp; \
    mv /tmp/eksctl /usr/local/bin; \
    eksctl version

curl -o aws-iam-authenticator https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator; \
    chmod 755 aws-iam-authenticator; \
    mv ./aws-iam-authenticator /usr/local/bin

eksctl create cluster  \
      --name "${AWS_CLUSTER_NAME}" \
      --version "${AWS_K8S_VERSION_SHORT}" \
      --nodegroup-name "${AWS_CLUSTER_NAME}-workers" \
      --node-type t3.xlarge \
      --nodes 1

sg=$(aws ec2 describe-security-groups --filter Name=tag:aws:eks:cluster-name,Values="${AWS_CLUSTER_NAME}" --query 'SecurityGroups[0].GroupId' --output text)

echo "security group is $sg"

## Setup security group rules
for i in {1..25}
do
    if [[ -n $sg  ]]; then
        break
    fi
    sleep 30
    echo attempt "$i" has failed
    sg=$(aws ec2 describe-security-groups --filter Name=tag:aws:eks:cluster-name,Values="${AWS_CLUSTER_NAME}" --query 'SecurityGroups[0].GroupId' --output text)
done

if [[ -z $sg  ]]; then
    echo "Security group is not found"
    exit 1
fi

# These steps are required to support CSI
eksctl utils associate-iam-oidc-provider --cluster="${AWS_CLUSTER_NAME}" --approve
eksctl create iamserviceaccount \
    --name "${IAM_NAME}" \
    --namespace kube-system \
    --cluster "${AWS_CLUSTER_NAME}" \
    --role-name AmazonEKS_EBS_CSI_DriverRole \
    --role-only \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve
ROLE_ARN=$(eksctl get iamserviceaccount --cluster "${AWS_CLUSTER_NAME}" -o json | jq -r '.[] | select(.metadata.name == env.IAM_NAME) | .status.roleARN')
eksctl create addon --name aws-ebs-csi-driver --cluster "${AWS_CLUSTER_NAME}" --service-account-role-arn "${ROLE_ARN}" --force

### authorize wireguard
aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol tcp --port 51820 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol udp --port 51820 --cidr 0.0.0.0/0
### authorize vxlan
aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol tcp --port 4789 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol udp --port 4789 --cidr 0.0.0.0/0
### authorize nsmgr-proxy
aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol tcp --port 5004 --cidr 0.0.0.0/0
### authorize registry
aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol tcp --port 5002 --cidr 0.0.0.0/0
### authorize vl3-ipam
aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol tcp --port 5006 --cidr 0.0.0.0/0


kubectl version --client