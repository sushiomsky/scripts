#!/bin/bash
LAN_IFACE = "wlan0"
WAN_IFACE = "eth0"

sysctl net.ipv4.conf.default.accept_redirects=1
/etc/init.d/network-manager stop
wpa_supplicant -B -iwlan0 -c/etc/wpa_supplicant/wpa_supplicant.conf
sleep 10
dhclient wlan0

ifconfig eth0 192.168.11.1

/etc/init.d/udhcpd restart
