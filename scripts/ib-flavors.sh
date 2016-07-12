#!/bin/bash

if [[ "$OS_USERNAME" != "admin" ]]; then
  echo "Setup must be done as OpenStack admin."
  exit 1
fi

nova flavor-create --is-public true vnios-100.55 auto 1024 55 1 --swap 0 --ephemeral 0
nova flavor-create --is-public true vnios-810.55 auto 2048 55 2 --swap 0 --ephemeral 0
nova flavor-create --is-public true vnios-820.55 auto 4096 55 2 --swap 0 --ephemeral 0
nova flavor-create --is-public true vnios-ND-800.160 auto 8192 160 2 --swap 0 --ephemeral 0
nova flavor-create --is-public true vnios-CP-V800.160 auto 2048 160 2 --swap 0 --ephemeral 0
nova flavor-create --is-public true vnios-1410.160 auto 8192 160 4 --swap 0 --ephemeral 0
nova flavor-create --is-public true vnios-1420.160 auto 15360 160 4 --swap 0 --ephemeral 0
nova flavor-create --is-public true vnios-2210.160 auto 15360 160 4 --swap 0 --ephemeral 0
nova flavor-create --is-public true vnios-2220.160 auto 15360 160 4 --swap 0 --ephemeral 0
