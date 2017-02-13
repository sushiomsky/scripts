#!/bin/bash

function stop_traffic {
	iptables-save > /tmp/saved
	iptables -F
	iptables -P INPUT DROP
	iptables -P OUTPUT DROP
	iptables -P FORWARD DROP
	
	iptables -A INPUT  -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED     -j ACCEPT
	
	iptables -A OUTPUT -p icmp -j ACCEPT
	iptables -A INPUT -p icmp -j ACCEPT
}

function restore_firewall {
	iptables-restore < /tmp/saved
}
if [ -z "$1" ]
  then
    echo "$0 ip"
    exit 1
fi

ifconfig wlan1 mtu 2304;
stop_traffic
for i in `seq 68 2048`; 
do 
	ping -W 1 -c 1 -M do $1 -s $i >/dev/null 2>&1; 
	
	if [ $? -ne 0 ]; then
		restore_firewall
		ifconfig wlan1 mtu $i;
		echo $i
		exit 0
	fi
done

