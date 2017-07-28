#!/bin/bash

# WAPI Calls for Adding a Member

GMIP=172.22.138.127
USER=admin
PASSWD=infoblox
NS_GROUP=default
MEMBER_IP=10.10.10.10
MEMBER_GW=10.10.10.1
MEMBER_MASK=255.255.255.0
MEMBER_NAME=member.localdomain
MEMBER_MODEL="IB-VM-820"
MEMBER_LICENSES='"enterprise", "dns", "dhcp"'

WAPI_VERSION="wapi/v2.6"

IS_SOT=false
if [[ $MEMBER_MODEL =~ 5$ ]]; then
    IS_SOT=true
fi

# Add NIOS license
# Use "nios" for SoT models; "vnios" otherwise
VNIOS_LICENSE='"vnios"'
if $IS_SOT ; then
    VNIOS_LICENSE="\"nios\", \"$MEMBER_MODEL\""
fi
MEMBER_LICENSES="${VNIOS_LICENSE}, ${MEMBER_LICENSES}"

echo Creating the member

MEMBER_REF=$(curl -H "Content-Type: application/json" -ks -u $USER:$PASSWD \
  -X POST https://$GMIP/$WAPI_VERSION/member -d@- <<EOF
{
    "platform": "VNIOS",
    "host_name": "$MEMBER_NAME",
    "vip_setting": {
        "address": "$MEMBER_IP",
        "gateway": "$MEMBER_GW",
        "subnet_mask": "$MEMBER_MASK"
    }
}
EOF
)

MEMBER_REF=${MEMBER_REF//\"/}
MEMBER_REF=${MEMBER_REF//\:/%3A}
echo Created member $MEMBER_REF

echo Pre-provisioning member
if $IS_SOT ; then
    HARDWARE_INFO="\"hwtype\": \"$MEMBER_MODEL\""
else
    HARDWARE_INFO="\"hwmodel\": \"$MEMBER_MODEL\", \"hwtype\": \"IB-VNIOS\""
fi
# Adding licenses using cloud-init - so licenses are not needed for preprovisioning call.
echo $(curl -H "Content-Type: application/json" -ks -u $USER:$PASSWD \
  -X PUT https://$GMIP/$WAPI_VERSION/$MEMBER_REF -d@- <<EOF
{
    "pre_provisioning": {
        "hardware_info": [
            {
                $HARDWARE_INFO
            }
        ],
        "licenses": [ ]
    }
}
EOF
)

echo Enable DNS on the member
DNS_REF=$(curl -sk -u admin:infoblox https://$GMIP/$WAPI_VERSION/member:dns?host_name=$MEMBER_NAME | grep _ref | cut -d: -f2-3 | tr -d '," ')
echo $(curl -sk -u admin:infoblox -X PUT -H "Content-Type: application/json" -d '{"enable_dns": true}' https://$GMIP/$WAPI_VERSION/$DNS_REF)

echo Add member to the NS group
echo Note: will erase any other secondaries
GROUP_REF=$(curl -sk -u admin:infoblox https://$GMIP/$WAPI_VERSION/nsgroup?name=$NS_GROUP | grep _ref | cut -d: -f2-3 | tr -d '," ')
SECONDARIES="{ \"name\": \"$MEMBER_NAME\" }"

echo $(curl -sk -u admin:infoblox -X PUT -H "Content-Type: application/json" -d "{\"grid_secondaries\": [$SECONDARIES]}" https://$GMIP/$WAPI_VERSION/$GROUP_REF)

echo Create the token for the member
MEMBER_REF=$(curl -sk -u admin:infoblox https://$GMIP/$WAPI_VERSION/member?host_name=$MEMBER_NAME | grep _ref | cut -d: -f2-3 | tr -d '," ')

TOKEN=$(curl -H "Content-Type: application/json" -ks -u $USER:$PASSWD \
  -X POST https://$GMIP/$WAPI_VERSION/$MEMBER_REF\?_function=create_token -d '{}' | grep '"token"' | cut -d: -f2 | tr -d '," ')
echo | openssl s_client -connect $GMIP:443 2>/dev/null | openssl x509 | sed -e 's/^/    /' > /tmp/cert.$$.pem

echo
echo TOKEN is $TOKEN
echo GM certificate is in /tmp/cert.$$.pem
echo user_data is in /tmp/user_data.$$.yaml
echo
echo You have 10 minutes until the token expires. Better hurry.
echo

LICENSES=$(echo $MEMBER_LICENSES | tr -d '" ')

cat <<EOF > /tmp/user_data.$$.yaml
#infoblox-config

remote_console_enabled: y
temp_license: $LICENSES
lan1:
  v4_addr: $MEMBER_IP
  v4_netmask: $MEMBER_MASK
  v4_gw: $MEMBER_GW
gridmaster:
  token: $TOKEN
  ip_addr: $GMIP
  certificate: |
EOF
cat /tmp/cert.$$.pem >> /tmp/user_data.$$.yaml

echo User data:
cat /tmp/user_data.$$.yaml
