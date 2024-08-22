#!/bin/bash
readonly AZURE_RESOURCE_GROUP=$1
readonly AZURE_CLUSTER_NAME=$2
readonly AZURE_CREDENTIALS_PATH=$3

if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then
    echo "Usage: aks-start.sh <resource-group> <cluster-name> <kube-config-path>"
    exit 1
fi

AKS_K8S_VERSION=$(echo "$K8S_VERSION" | cut -d '.' -f 1,2 | cut -c 2-)

echo -n "Creating AKS cluster '$AZURE_CLUSTER_NAME'..."
az aks create \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$AZURE_CLUSTER_NAME" \
    --kubernetes-version "$AKS_K8S_VERSION" \
    --node-count 1 \
    --node-vm-size Standard_B2s \
    --enable-node-public-ip \
    --generate-ssh-keys \
    --debug && \
    echo "az aks create done" || exit 3
echo "Waiting for deploy to complete..."
az aks wait  \
	--name "$AZURE_CLUSTER_NAME" \
	--resource-group "$AZURE_RESOURCE_GROUP" \
	--created > /dev/null && \
echo "az aks wait done" || exit 4

NODE_RESOURCE_GROUP=$(az aks show -g "$AZURE_RESOURCE_GROUP" -n "$AZURE_CLUSTER_NAME" --query nodeResourceGroup -o tsv)
echo NODE_RESOURCE_GROUP="$NODE_RESOURCE_GROUP"
NSG_NAME=""
for i in {1..25}
do
    NSG_NAME=$(az network nsg list -o tsv --query "[? resourceGroup == '$NODE_RESOURCE_GROUP'].name")
    if [[ -n $NSG_NAME  ]]; then
        break
    fi
    NSG_NAME=$(az network nsg list -g "$NODE_RESOURCE_GROUP" --query "[].name" -o tsv)
    if [[ -n $NSG_NAME  ]]; then
        break
    fi
    sleep 30
    echo attempt "$i" has failed
done

if [[ -z $NSG_NAME  ]]; then
    echo NSG_NAME is empty. Creating custom NSG...
    NSG_NAME="nsmnsg"
    az network nsg create -g "$NODE_RESOURCE_GROUP" -n "$NSG_NAME"
    NSG_NAME=$(az network nsg list -g "$NODE_RESOURCE_GROUP" --query "[0].name" -o tsv)
fi

echo NSG_NAME="$NSG_NAME"

if [[ -z $NSG_NAME  ]]; then
    echo "NSG is not found for resource group $NODE_RESOURCE_GROUP"
    exit 5
fi

az network nsg rule create --name "allowall" \
    --nsg-name "$NSG_NAME" \
    --priority 100 \
    --resource-group "$NODE_RESOURCE_GROUP" \
    --access Allow \
    --description "Allow All Inbound Internet traffic" \
    --destination-address-prefixes '*' \
    --destination-port-ranges '*' \
    --direction Inbound \
    --protocol '*' \
    --source-address-prefixes Internet \
    --source-port-ranges '*' && \
echo "az network nsg rule create done" || exit 6

mkdir -p "$(dirname "$AZURE_CREDENTIALS_PATH")"
az aks get-credentials \
    --name "$AZURE_CLUSTER_NAME" \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --file "$AZURE_CREDENTIALS_PATH" \
    --overwrite-existing || exit 7