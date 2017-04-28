#!/bin/bash

ip=${1:-you-should-pass-the-ip}


#scp  ntp.conf core@$ip:
#ssh -t core@$ip 'sudo cp ntp.conf /etc; sudo systemctl restart ntpd; sleep 2 ; ntpdc peers'


#scp  chrony.conf centos@$ip:
#ssh -t centos@$ip 'sudo cp chrony.conf /etc; sudo systemctl restart chronyd; sleep 2 ; chronyc activity'
#ssh -t centos@$ip 'sudo yum install -y docker'
#ssh -t centos@$ip 'sudo systemctl start docker'
