#!/bin/bash

STACK=${1:-gm-ha}

if [[ -z "$OS_USERNAME" ]]; then
	echo "You must set up your OpenStack environment (source an openrc.sh file)."
	exit 1
fi

source ./grid-lib.sh

# main

# set all the resource names equal to the IDs

#resource_name
#ha_port_node_2
#lan1_port_node_2
#node_1_floating_ip
#node_2
#node_2_floating_ip
#vip_floating_ip
#ha_port_node_1
#lan1_port_node_1
#node_1
#vip_port

wait_for_stack $STACK

eval $(heat resource-list $STACK  | cut -f 2,3 -d\| | tr -d ' ' | grep -v + | tr '|' '=')

# Get the various IPs for each node
VIP=$(port_first_fixed_ip $vip_port)
VIP_FIP=$(neutron floatingip-show -c floating_ip_address -f value $vip_floating_ip)
GW=$(port_gw $vip_port)
N1_FIP=$(neutron floatingip-show -c floating_ip_address -f value $node_1_floating_ip)
N1_LAN=$(port_first_fixed_ip $lan1_port_node_1)
N1_HA=$(port_first_fixed_ip $ha_port_node_1)
N2_FIP=$(neutron floatingip-show -c floating_ip_address -f value $node_2_floating_ip)
N2_LAN=$(port_first_fixed_ip $lan1_port_node_2)
N2_HA=$(port_first_fixed_ip $ha_port_node_2)


wait_for_ping $N1_FIP
wait_for_ssl $N1_FIP
wait_for_wapi $N1_FIP

echo "Setting Networking Parameters for HA on Node 1..."
grid_set_ha $N1_FIP $(gm_ref $N1_FIP) $VIP $GW $N1_LAN $N1_HA $N2_LAN $N2_HA

wait_for_ping $VIP_FIP
wait_for_ssl $VIP_FIP
wait_for_wapi $VIP_FIP

grid_join $VIP $N2_FIP

grid_snmp $VIP_FIP
grid_dns $VIP_FIP
grid_nsgroup $VIP_FIP
write_env $VIP_FIP $VIP $vip_floating_ip

echo
echo HA GM is now configured and ready.
echo You may add a member via:
echo
echo heat stack-create -e gm-$VIP_FIP-env.yaml -f member.yaml member-1
echo
