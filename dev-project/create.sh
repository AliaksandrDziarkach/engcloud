#!/bin/bash

USERNAME=${1}
PROJECT_NAME=${2:-$USERNAME}

if [[ "$OS_USERNAME" != "admin" ]]; then
  echo "Project creation must be done as OpenStack admin."
  exit 1
fi

if [[ -z "$USERNAME" ]]; then
  echo "usage: $0 <username> [ <projectname> ]"
  echo "Creates a new project and user."
  echo "Specify a user name (no spaces), and optionally a project name."
  exit 1
fi

openstack project create $PROJECT_NAME
PROJECT_ID=$(openstack project show $PROJECT_NAME | grep ' id ' | cut -d \| -f 3 | tr -d ' ')
openstack quota set --ram 102400 --cores 24 $PROJECT_ID
openstack user create $USERNAME --project $PROJECT_NAME --password infoblox
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

echo "Project $PROJECT_NAME created. You may access it using:"
echo "source ./$USERNAME-openrc.sh"
echo
echo "You can then setup the basic network topology and launch a control VM with:"
echo "heat stack-create -e $USERNAME-env.yaml -f control.yaml control"
echo

