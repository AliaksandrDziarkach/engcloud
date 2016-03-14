#!/bin/bash

STACK=${1:-gm-ha}

if [[ -z "$OS_USERNAME" ]]; then
	echo "You must set up your OpenStack environment (source an openrc.sh file)."
	exit 1
fi


## FUNCTIONS

function port_first_fixed_ip() {
	neutron port-show -c fixed_ips -f value $1 | sed -e 's/.*ip_address": "\([0-9\.]*\)".*/\1/'
}

function port_gw() {
	subnet_id=$(neutron port-show -c fixed_ips -f value $1 | sed -e 's/.*"subnet_id": "\([-a-z0-9]*\)", .*/\1/')
	neutron subnet-show -c gateway_ip -f value $subnet_id
}

function wait_for_ping() {
	ip=$1
	ping -c 1 $ip 1>/dev/null 2>&1
	wait=$?
	while [ "$wait" -ne "0" ]
	do
  		echo $(date): Could not ping $ip yet...waiting...
  		sleep 15
		ping -c 1 $ip 1>/dev/null 2>&1
  		wait=$?
	done

	echo
	echo $(date): Ping $ip successful.
	echo
}

function wait_for_ssl() {
	ip=$1
	echo | openssl s_client -connect $ip:443 >/dev/null 2>&1
	wait=$?
	while [ "$wait" -ne "0" ]
	do
  		echo $(date): Could not connect to HTTPS...waiting...
  		sleep 15
  		echo | openssl s_client -connect $ip:443 >/dev/null 2>&1
  		wait=$?
	done
}

function grid_ref() {
	ip=$1
	curl -sk -u admin:infoblox https://$ip/wapi/v2.3/grid | grep _ref | cut -d: -f2-3 | tr -d '," '
}

function gm_ref() {
	ip=$1
	curl -sk -u admin:infoblox https://$ip/wapi/v2.3/member?host_name=infoblox.localdomain | grep _ref | cut -d: -f2-3 | tr -d '," '
}

function wait_for_wapi() {
	ip=$1
	ref=""
	while [[ -z "$ref" ]]; do
		echo $(date): Waiting for WAPI...
		ref=$(grid_ref $ip)
	done

	echo 
	echo $(date): Done - grid $ref
	echo
}

function download_cert() {
	ip=$1
	file=$2
	echo $(date): Downloading certificate from $ip for use in member join...
	echo
	echo | openssl s_client -connect $ip:443 2>/dev/null | openssl x509 | sed -e 's/^/    /' > $file
	echo $(date): Done
}


function grid_set_ha() {
	fip=$1
	ref=$2
	vip=$3
	gw=$4
	n1lan=$5
	n1ha=$6
	n2lan=$7
	n2ha=$8
	echo "On $fip, setting $ref networking to (vip=$vip, gw=$gw, n1lan=$n1lan, n1ha=$n1ha, n2lan=$n2lan, n2ha=$n2ha)..."
	echo $(curl -sk -u admin:infoblox -X PUT -H 'Content-Type: application/json' -d "{\"enable_ha\": true, \"router_id\": 200, \"vip_setting\": {\"address\": \"$vip\", \"gateway\": \"$gw\", \"subnet_mask\": \"255.255.255.0\" }, \"node_info\": [{\"lan_ha_port_setting\": { \"ha_ip_address\": \"$n1ha\", \"mgmt_lan\": \"$n1lan\"}}, {\"lan_ha_port_setting\": {\"ha_ip_address\": \"$n2ha\", \"mgmt_lan\": \"$n2lan\"}}]}" https://$fip/wapi/v2.3/$ref)
	echo
}

function grid_join() {
	vip=$1
	fip=$2
	
	echo "Joining $fip to grid at $vip..."
	ref=$(grid_ref $fip)
	echo $(curl -sk -u admin:infoblox -X POST "https://$fip/wapi/v2.3/$ref?_function=join&master=$vip&shared_secret=test&grid_name=Infoblox")
	echo
}

function grid_snmp() {
	fip=$1
	echo "Enabling SNMP..."
	echo $(curl -sk -u admin:infoblox -X PUT -H "Content-Type: application/json" -d '{"snmp_setting": {"queries_enable": true, "queries_community_string": "public"}}' https://$fip/wapi/v2.3/$(grid_ref $fip))
}


function grid_dns() {
	fip=$1
	echo "Enabling DNS..."
	echo $(curl -sk -u admin:infoblox -X PUT -H "Content-Type: application/json" -d '{"enable_dns": true}' https://$fip/wapi/v2.3/$(grid_ref $fip))
}

function grid_nsgroup() {
	fip=$1
	echo "Adding a default nsgroup..."
	echo $(curl -sk -u admin:infoblox -X POST -H "Content-Type: application/json" -d '{"name": "default", "is_grid_default": true, "grid_primary": [{"name": "infoblox.localdomain"}]}' https://$fip/wapi/v2.3/nsgroup)
}

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

eval $(heat resource-list gm-ha  | cut -f 2,3 -d\| | tr -d ' ' | grep -v + | tr '|' '=')

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
GM_REF=$(gm_ref $N1_FIP)
grid_set_ha $N1_FIP $GM_REF $VIP $GW $N1_LAN $N1_HA $N2_LAN $N2_HA

wait_for_ping $VIP_FIP
wait_for_ssl $VIP_FIP
wait_for_wapi $VIP_FIP

download_cert $VIP_FIP /tmp/gm-$VIP_FIP-cert.pm

grid_join $VIP $N2_FIP

grid_snmp $VIP_FIP
grid_dns $VIP_FIP
grid_nsgroup $VIP_FIP

FIP_NET_ID=$(neutron floatingip-show -c floating_network_id -f value $node_1_floating_ip)
FIP_NET=$(neutron net-show -c name -f value $FIP_NET_ID)

cat > gm-$VIP_FIP-env.yaml <<EOF
# Heat environment for launching autoscale against GM $VIP_FIP
parameters:
  gm_vip: $VIP
  external_network: $FIP_NET
  gm_cert: |
EOF

cat >> gm-$VIP_FIP-env.yaml < /tmp/gm-$VIP_FIP-cert.pem

cat >> gm-$VIP_FIP-env.yaml <<EOF
parameter_defaults:
  wapi_url: https://$VIP_FIP/wapi/v2.3/
  wapi_username: admin
  wapi_password: infoblox
  wapi_sslverify: false
EOF

echo
echo HA GM is now configured and ready.
echo You may add a member via:
echo
echo heat stack-create -e gm-$VIP_FIP-env.yaml -f member.yaml member-1
echo
