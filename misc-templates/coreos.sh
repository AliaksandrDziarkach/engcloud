#!/bin/bash


KEY=$1
SIZE=${2:-3}
CLUSTER_NAME=${3:-coreos-cluster}
FLAVOR=${4:-m1.small}

if [[ -z "$KEY" ]];
then
	echo "Usage: $0 <key-name> [ <cluster-size> [ <custer-name> [ <flavor> ] ] ]"
	exit 1
fi

token=$(curl -s https://discovery.etcd.io/new?size=$SIZE)
token=${token##*/}

echo $token

heat stack-create -f coreos-cluster.yaml -P"cluster_size=$SIZE;discovery_token=$token;key_name=$KEY;flavor=$FLAVOR;name=$CLUSTER_NAME" $CLUSTER_NAME
