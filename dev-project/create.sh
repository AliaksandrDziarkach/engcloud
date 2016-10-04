#!/bin/bash

USERNAME=${1}
PROJECT_NAME=${2:-$USERNAME}
EMAIL=${3}
ADMIN_EMAIL=${4:-jbelamaric@infoblox.com}

if [[ "$OS_USERNAME" != "admin" ]]; then
  echo "Project creation must be done as OpenStack admin."
  exit 1
fi

if [[ -z "$USERNAME" ]]; then
  echo "usage: $0 <username> [ <projectname> ] [ email ]"
  echo "Creates a new project and user."
  echo "Specify a user name (no spaces), and optionally a project name."
  exit 1
fi

openstack project create $PROJECT_NAME
PROJECT_ID=$(openstack project show $PROJECT_NAME | grep ' id ' | cut -d \| -f 3 | tr -d ' ')
openstack quota set --ram 102400 --cores 24 $PROJECT_ID

email=""
if [[ ! -z "$EMAIL" ]]; then
	email="--email $EMAIL"
fi

openstack user create $USERNAME --project $PROJECT_NAME --password infoblox $email
openstack role add --user $USERNAME --project $PROJECT_NAME user

cat > $USERNAME-env.yaml <<EOF
parameters:
  username: $USERNAME
  project_name: $PROJECT_NAME
  os_auth_url: $OS_AUTH_URL
EOF

cat > $USERNAME-openrc.sh <<EOF
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=$PROJECT_NAME
export OS_TENANT_NAME=$PROJECT_NAME
export OS_USERNAME=$PROJECT_NAME
export OS_PASSWORD=infoblox
export OS_AUTH_URL=$OS_AUTH_URL
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

echo "Project $PROJECT_NAME created. Creating control VM."
source ./$USERNAME-openrc.sh
heat stack-create -e $USERNAME-env.yaml -f control.yaml control

FIP=""
while [[ -z "$FIP" ]]; do
	echo Checking for FIP...
	FIP=$(neutron floatingip-list | grep -E '[0-9]' | cut -d \| -f 4 | tr -d ' ')
done

echo "FIP is $FIP"

cat > /tmp/$USERNAME-msg.txt <<EOF
To: $EMAIL
CC: $ADMIN_EMAIL
From: EngCloud Admin <noreply@engcloud.infoblox.com>
Subject: New user $USERNAME for EngCloud

Hello,

You now have an account on the engineering OpenStack Lab Cloud (EngCloud).

Your username is $USERNAME and your password is "infoblox".

Horizon: http://engcloud.infoblox.com

You also have a control node (VM) already up and running. You can login to
that node and it already has your OpenStack credentials sourced into your
environment. So, you can login an immediately run CLI commands for OpenStack
(e.g., nova list will show you your VMs). You can connect to your control node
with:

  ssh $USERNAME@$FIP

Your password is "infoblox". It may take 10 minutes or so from the sending
of this email until the account is working on that node.

If you want to try building a grid, you'll want to grab two GitHub repositories
to get access to some pre-built templates. So, first thing logging into your
nodes:

  $ sudo apt-get install git
  $ git clone https://github.com/infobloxopen/engcloud
  $ git clone https://github.com/infobloxopen/heat-infoblox

In engcloud/grid-templates you'll want to create the "simple-net" which is the
basis for the other templates in there as well as the ones in the
heat-infoblox/doc/templates directory.

  $ cd engcloud/grid-templates
  $ heat stack-create -f simple-net.yaml simple-net

Then maybe create a GM:

  $ heat stack-create -f gm.yaml gm
  $ ./config-gm.sh

REMEMBER THIS IS A LAB. IT WILL BREAK. FREQUENTLY.

USE AT YOUR OWN RISK. SOME NOTES:

	1) This is an engineering lab with no guarantees of availability. To be
           clear, the two controller machines it is using are 7 years old and
           have single disks and single power supplies. 

        2) It is used by several dev engineers, QA, TMEs, SEs and others.  It
           is a very small cloud (currently 3 compute nodes with a total of 112
           physical cores, 315GB of RAM, and 4.5TB of storage) so it may hit
           capacity limits before long. If you are experimenting, PLEASE use
           tiny Cirros instances whenever possible.

        3) For auto-scaling, the member statistics are only polled every 10
           minutes. This can make it a long delay when trying to scale.

Enjoy.

EOF

if [[ ! -z "$EMAIL" ]]; then
	echo "Sending mail to $EMAIL"
	sendmail $EMAIL $ADMIN_EMAIL < /tmp/$USERNAME-msg.txt
else
	echo '******'
	cat /tmp/$USERNAME-msg.txt
	echo '******'
fi

