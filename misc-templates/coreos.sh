#!/bin/bash


KEY=$1
SIZE=${2:-3}
CLUSTER_NAME=${3:-coreos-cluster}

if [[ -z "$KEY" ]];
then
	echo "Usage: $0 <key-name> [ <cluster-size> [ <custer-name> ] ]"
	exit 1
fi

token=$(curl -s https://discovery.etcd.io/new?size=$SIZE)
token=${token##*/}

echo $token

heat stack-create -f coreos-cluster.yaml -P"cluster_size=$SIZE;discovery_token=$token;key_name=$KEY" $CLUSTER_NAME
