Grid Templates and Scripts
==========================

This directory contains templates and scripts for building grids.

Summary of Templates and Scripts
--------------------------------

*simple-net.yaml* - Creates a basic network for a grid.

*gm.yaml* - Creates a grid master, based on `simple-net.yaml`.

*config-gm.sh* - Configures the basics for a standalone GM that was created
using `gm.yaml`.

*gm-ha.yaml* - Creates an HA grid master, based on `simple-net.yaml`. The HA
configuration on the grid itself is handled by `config-gm-ha.sh`.

*config-gm-ha.sh* - Configures HA on nodes created via `gm-ha.yaml`, and
basic DNS features as well.

*member.yaml* - Adds a single member to an existing grid.


Creating the Network
--------------------
The grids built here are based on the networks defined in ``simple-net.yaml``.
This builds a router, a management network, a protocol network, and a
security group, and wires them all together as needed. This is the minimum
needed to get a grid up and running. So, the first thing you need to do is
create that stack:

::

  $ heat stack-create -f simple-net.yaml simple-net

Creating a Grid Master
----------------------
Next, we need to build a GM for our new grid. There are templates and scripts
for building a single-node GM as well as for an HA GM. The single-node one
is good enough for most tests, and uses fewer resources. Please use that one
whenever possible.

To set up a standalone GM, you use the ``gm.yaml`` template. Optionally, you can
also run the ``config-gm.sh`` script to set up a basic configuration on the GM.

::

  $ heat stack-create -f gm.yaml gm

Running ``config-gm.sh`` will enable SNMP grid-wide and DNS on the GM, and also
create a name server group 'default'. More importantly, it generates a yaml
environment file you can use in later commands when adding members to the grid.

::

  $ ./config-gm.sh 

This results in a file like "gm-<ip>-env.yaml". This file will be used later.

Setting up a highly available GM is done similarly. The Neutron setup for this
is a little tricky, but the ``gm-ha.yaml`` takes care of all of it. Then, the
``config-gm-ha.sh`` script will configure the HA on both nodes.

::

  $ heat stack-create -f gm-ha.yaml gm-ha
  $ ./config-gm-ha.sh

When this is complete, you can login to the floating IP of the VIP. Note that
the VIP floating IP will NOT show up in the instance list. Those are the
floating IPs for the LAN1 interfaces of each node. Instead, you need to
look at the gm-ha stack details in the Orchestration section, which includes
and output with the VIP floating IP. Alternatively, you can look in the
Floating IPs section and find the floating IP listed that does not show the
fixed IP - this one is the for the VIP.

You will need to step through the EULA and set up wizard. As far as I know
there is no WAPI to avoid those.

Adding Members
--------------

The default GM flavors allow members (you can adjust the image and flavor in
parameters, if you wish). So, let's add a member. The ``member.yaml`` provides
the basics needed to launch a member and have it automatically join the grid.

::

  $ heat stack-create -e gm-<ip>-env.yaml -f member.yaml member-1

Notice the ``-e``. That passes in all the information needed by the member
to join the grid. For example, the WAPI connectivity for the GM, and
the GM VIP and certificate.

Enhancements
------------
It should be pretty easy to add enhancements or to script all of this to build
out grids of arbitrary complexity. There is no reason that all the members need
to be on the same networks - you could create various network topologies and
put members in different subnets.

Note that some pieces that are scripted right now in the shell will eventually
move to Heat - for example, some of the ``config-gm-ha.sh`` will be replaced
when we implement Heat resources to launch HA members.

The basic functions used by these scripts are in ``grid-lib.sh``; any re-usable
functions should be added there.

Note that some of these YAML files allow various parameters, such as the
particular image/model/flavor of VM to spin up. With some effort, it should
be pretty straightforward to build up a set of templates that enable a very
dynamic system for building up grids. For example, adding templates that
enable grids with CP, reporting, and discovery members.
