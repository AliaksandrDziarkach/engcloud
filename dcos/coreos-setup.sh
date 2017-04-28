#!/bin/bash

IP=$1

if [[ ! -z "$IP" ]]; then
  scp $0 core@$IP:
  scp infoblox-plugin core@$IP:
  ssh -t core@$IP ./coreos-setup.sh
  exit 0
fi

# The rest will run on every host
cat > /tmp/$$.cni <<EOF
{
 "name": "container-net",
 "type": "bridge",
 "bridge": "cni01",
 "ipam": {
   "type": "infoblox",
   "subnet": "10.20.0.0/22",
   "routes": [{"dst": "0.0.0.0/0", "gw": "10.20.0.1"}],
   "network-view": "default"
  }
}
EOF

sudo cp /tmp/$$.cni /opt/mesosphere/etc/dcos/network/cni/container-net.cni
sudo cp infoblox-plugin /opt/mesosphere/active/cni/infoblox

sudo brctl addbr cni01
sudo brctl addif cni01 eth1
sudo ip link set dev eth1 up

brctl show cni01

#!/bin/bash

DRIVER_NAME="infoblox"
SOCKET_DIR="/run/cni"
GRID_HOST="172.22.138.18"
WAPI_PORT="443"
WAPI_USERNAME="admin"
WAPI_PASSWORD="infoblox"
WAPI_VERSION="2.0"
SSL_VERIFY=false
NETWORK_VIEW="default"
NETWORK_CONTAINER="10.0.0.0/16"
PREFIX_LENGTH=24


docker run -d -v /run/cni:/run/cni infoblox/infoblox-cni-daemon --grid-host=${GRID_HOST} --wapi-port=${WAPI_PORT} --wapi-username=${WAPI_USERNAME} --wapi-password=${WAPI_PASSWORD} --wapi-version=${WAPI_VERSION} --socket-dir=${SOCKET_DIR} --driver-name=${DRIVER_NAME} --ssl-verify=${SSL_VERIFY} --network-view=${NETWORK_VIEW} --network-container=${NETWORK_CONTAINER} --prefix-length=${PREFIX_LENGTH}

