#!/bin/bash


token=$(curl -s https://discovery.etcd.io/new?size=$SIZE)
token=${token##*/}

echo $token

# you need to create a key pair "mddi" or change the one below

heat stack-create -f dcos-coreos-cluster.yaml -P"discovery_token=$token;key_name=jbelamaric-cloud-key;name=dcos;mgmt_network=dcos-mgmt-net" dcos-cluster
