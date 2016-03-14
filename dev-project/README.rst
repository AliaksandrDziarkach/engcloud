=================================
Dev Project Templates and Scripts
=================================

Scripts and Heat templates for setting up dev projects.

Usage
-----

::

  $ ./create.sh <user>
  $ source ./<user>-openrc.sh
  $ heat stack-create -e <user>-env.yaml control.yaml

`create.sh` creates a tenant and a user, and adds the user and admin to that
tenant.

`control.yaml` creates a stack that includes a dev network, router, and
a VM named 'control' with a user account for the specified user. This VM will
also have <user>-openrc.sh in the home directory, and that file will be sourced
automatically. So, logging in as the user to that VM, you should be able to run
OpenStack clients immediately.

`devstack.yaml` can be used to create a nested devstack instance, with the
ceilometer-infoblox and heat-infoblox plugins enabled. You may specify the
fork of those as well as the devstack branch to use via input parameters:

::

  $ heat stack-create -f devstack.yaml -P"branch_name=stable/kilo" devstack

will create a Kilo environment. Once the VM is up and running, you login with
credentials stack/infoblox. View the local.conf and modify as needed - some
tweaks may be needed depending which branch you chose.
