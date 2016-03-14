#!/bin/bash

STACK=${1:-gm}

if [[ -z "$OS_USERNAME" ]]; then
	echo "You must set up your OpenStack environment (source an openrc.sh file)."
	exit 1
fi

source ./grid-lib.sh

# main

# set all the resource names equal to the IDs

#resource_name
#floating_ip
#gm
#lan1_port

wait_for_stack $STACK

eval $(heat resource-list $STACK  | cut -f 2,3 -d\| | tr -d ' ' | grep -v + | tr '|' '=')

# Get the various IPs for each node
FIP=$(neutron floatingip-show -c floating_ip_address -f value $floating_ip)
GW=$(port_gw $lan1_port)
LAN=$(port_first_fixed_ip $lan1_port)

wait_for_ping $FIP
wait_for_ssl $FIP
wait_for_wapi $FIP

grid_snmp $FIP
grid_dns $FIP
grid_nsgroup $FIP
write_env $FIP $LAN $floating_ip

echo
echo GM is now configured and ready.
echo You may add a member via:
echo
echo heat stack-create -e gm-$FIP-env.yaml -f member.yaml member-1
echo
