#!/bin/bash

if [[ "$OS_USERNAME" != "admin" ]]; then
  echo "Flavor creation must be done as OpenStack admin."
  exit 1
fi

# Create some basic flavors for use in EngCloud

nova flavor-create '1/4GB/40GB' auto 4096 40 1
nova flavor-create '4/6GB/40GB' auto 6144 40 4

