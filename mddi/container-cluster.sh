#!/bin/bash


token=$(curl -s https://discovery.etcd.io/new?size=$SIZE)
token=${token##*/}

echo $token

# you need to create a key pair "mddi" or change the one below

heat stack-create -f container-cluster.yaml -P"discovery_token=$token;key_name=mddi" container-cluster
