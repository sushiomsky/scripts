#!/bin/bash
#
# freewifi_autoconnect.sh: Auto connect to open (and online) WIFI(s), with trying all WLAN devices.
# It scanns for free WIFIs and connects to the one with the best quality.
# It checks if the WIFI/access point is really online.
# If no open and online WIFI could be connected or after a disconnect it
# restarts with a new and fast scan for WIFIs, to make the PC nearly always
# online.
# To avoid problems with duplicate ESSIDs and hidden ESSIDs this script uses
# MACs.
# The error "Operation not possible due to RF-kill" is usually caused by an deactivated device, e. g. via a WiFi switch.
# This script needs the common environment, e. g. NO null globbing.
#
# Because DHCP changes /etc/resolv.conf, you should check that file when you use a network without DHCP afterwards.
#
# DHCP Clients in this script:
# The default is to use dhcpcd and if it is not availible dhclient will be used.
# dhcpcd runs in background and actively manages re-requests after expired
# lease time etc. pp. without needing to be called again while dhclient only
# requests an IP (and gateway etc.) and then exits.
# dhcpcd does not exit when the lease time is infinite but that should be no big
# problem because with an infinite lease time re-requests are not necessary.
# So dhcpcd is better and should be installed but this script also works with dhclient.
#
# 2012-06: Added optional parameters: The first for autoconnect (1 for true, 0 for only scanning), which is usefull
# for scanning (WiFi monitoring), the second is the filter for connecting: The ESSID must be equal, which is usefull
# for selecting wifis, the third is the inverse filter, for connecting this ESSID will be ignored, wich is usefull
# for not connecting WiFis, e. g. known honeypots.
# The first parameter is NOT optional if other parameter are used!
# Example: ./freewifi_autoconnect.sh 0.
# This does not connect (only scanning).
# This filtering works only at connecting WiFis. If you want to filter the output, you have to filter e. g. via
# ./freewifi_autoconnect.sh 2>&1 | grep "Tonline"
# or
# ./freewifi_autoconnect.sh 2>&1 | grep -v "Tonline"
#
# 2012-09: Added output for the wifiscan program, for exponential smoothing of the WiFi Quality and Signal Level,
# and sorting due to one of the parameters (Channel, MAC, ESSID, ...).
# The output fomat is CSV: <Channel>,<Encryption>,<Quality>,<Level>,<MAC>,<ms-time>,"<ESSID>",
# with file names of format: <MAC>,<Channel>,<hexdump of "<ESSID>">,<ms-time>
# To ensure that "form follows function" and not to waste time by formatting the script, the script is now
# formatted with the Bash Script Beautifier beautify_bash.py from http://www.arachnoid.com/python/python_programs/beautify_bash.py,
# called with only this script as parameter.
#
# 2013-04: Added the country setting for the region NZ to minimize the difference between the transmission range and
#	   reception range by setting TxPower to 500 mW. This works with my adapter WL0162 under openSuSE 12.3 and Kubuntu 12.10,
#          but the values measures with a WiFi router and RFExplorer do show no change.
#          -
#          Second changes: Skipping of IPV4LL addresses and no setting of the channel with iwconfig, because the 2013
#          version of iwconfig can't do that and also does not set the other parameters, so that DHCP can't work.
#          I also removed the wget option --proxy=off because DHCP can set a proxy, wget automatically uses a
#          proxy (via the environment variables) and this script starts with unsetting the proxy environment variables.
#          So this script can go online even behind an dual-homed bastion host.
#          More general scanning of the iwlist output and using only "wlan" devices, because that seems to be the only way
#          of finding WiFi devices. This works with the dozen old WiFi adapters and my new one.
#          Added showing of the external IP and setting a low MTU, because tests with weak connections worked much better
#          with an MTU of 512.
# 2013-09-09: Shorter timeouts, eleminated the bug of endeless looping after the connection got lost. Works well with free WiFis
#          and with lost connections. After about 40 seconds a dead connection gets terminated and the seaarch for a new connection
#          starts.
# 2013-10-08: Added timeout from the coreutils to the dhclient command, because it sometimes hangs. Shorter timeout for dhcpcd.
# 2013-10-19: Added -A option to dhcpcd, enabled rts handshaking and increase the retry level to 30.
# 2013-10-20: Set dhclient as default DHCP client program because in my first test configuration after dhcpcd the dig does NOT work!
#             In another configuration i could see the problem that only dhcpcd could get an IP from the AP, so sometimes
#             dhclient should be used and sometimes dhcpcd should be used.
#	      Added coreutils timeout to wget because even with --tries 1 wget does 6 tries.
# 2013-11-08: Several changes because changing the MAC via ifconfig does not work anymore and macchanger is not the right tool
#             for most WiFi adapters because at several only a few bits of the MAC can be toggled.
#             Added online-help and orthogonalised the filtering of AP names.
# 2013-12-05: Added mode 4 for radio links, which does connection checking with simple pings to the AP.
# 2014-05-10: Now it works with ESSIDs with double dots, e. g. re:publica.
# 2015-02:    Mode 4 (first parameter is 4, checking the connection only by ICMP pinging the AP) tests passed in hotels with a slow
#             internet connection, added Mode 5 which is like 4 but with ARP instead of ICMP pinging the AP, because more and more 
#             APs do a) not connect to the internet directly and b) do not answer ICMP pings. I found this in a hotel in Santiago 
#             (Chile), in an Iberia airplane (IBE6830) and on the international airport Madrid. In the plane and at the airport
#             the new mode 5 worked without problems.
# 2015-06:    Changed the scanning of the channel number, which did not work for channel numbers greater 100.
# 2017-01:    Changed the extraction of the MAC, because the format of the ifconfig output has changed.
#
# TODO: ESSIDs with wildcards or spaces as command line option or in a file.

# ----------------------------------------------------------------------------
# "THE BEERWARE LICENSE" (Revision 44):
# Dr. Rolf Freitag (rolf dot freitag at email dot de) wrote this file.
# As long as you retain this notice you can do whatever
# the GPL (GNU Public License version 3) allows with this stuff.
# If you think this stuff is worth it, you can send me money via
# paypal, and get a contribution receipt if you wish, or if we met some day
# you can buy me a beer in return.
# ----------------------------------------------------------------------------

# Dr. Rolf Freitag, 2010 - ...

# Simple version number (date of last coding)
VERSION=2017-01-04

# set -u : Stop the script when a variable isn't set (add -x for debugging)
set -u #-x


# Check the first parameter for online-help and invalid parameters or invalid number of parameters
if [[ ("$#" -gt 0) && ("--help" = "$1") || ("$#" -gt 2) || ("$#" -gt 0) && ("$1" -lt 0) || ("$#" -gt 0) && ("$1" -gt 5) || ("$#" -gt 0) && ("$1" -gt 1) && ("$#" -lt 2) ]]
then
  echo "Usage: $0 <--help> or $0 <0 ... 5>  <ESSID>"
  echo
  echo "This ist version $VERSION."
  echo "Without options or 1 the script uses one WiFi adapter after the other for scanning for free WiFis, connecting them"
  echo "and testing the internet connection with a) DNS resolving and b) small test downloads."
  echo "In the background the actual scanning result is stored in /tmp/wifiscan, for the wifiscan program which does"
  echo "exponential smoothing, to eleminate most of the noise for locating APs or optimisation of parameters like the"
  echo "antenna orientation. That program lists the APs sorted by channel or ESSID or level or or other parameter, commanded"
  echo "via the numeral keys."
  echo "For maximum range and best distortion immunity a data rate of 1 Mbit/s and a transmission power of 500 mW is used."
  echo "For Knoppix the script creates the file /home/knoppix/Desktop/online when the status is online."
  echo "To get away from the connected access point and check the next strongest free WiFi you only have to do"
  echo
  echo "  touch /var/tmp/next_wifi_please"
  echo
  echo "With the first parameter --help this script shows this help. The first paramter, an integer number, sets the mode"
  echo "of this script, e. g. only scanning or connecting only to an specified ESSID (second option)."
  echo
  echo "With only the parameter 0 the script does only scanning (and could also work in monitor mode)."
  echo
  echo "With the first parameter 2 and the second parameter (<ESSID>) the script does NOT connect"
  echo "to acces points with that ESSID, but to all others."
  echo
  echo "With the first parameter 3 and the second parameter (<ESSID>) the script does try only to"
  echo "connect to acces points with that ESSID."
  echo
  echo "With the first parameter 4 and the second parameter (<ESSID>) the script does try only to"
  echo "connect to acces points with that ESSID and does only check if (ICMP) pinging the AP works."
  echo "This mode 4 is similar to the mode 3 and usefull for APs which are offline or have a slow/high"
  echo "latency internet connection."
  echo
  echo "With the first parameter 5 and the second parameter (<ESSID>) the script does try only to"
  echo "connect to acces points with that ESSID and does only check if (ARP) pinging the AP works."
  echo "This is usefull for APs which are offline or have a slow/high latency internet connection,"
  echo "and which do not answer ICMP pings. This mode 5 is generally more reliable than mode 4."
  echo
  echo "Examples:"
  echo
  echo "  $0"
  echo
  echo "does try to connect open WiFis, in the order of the signal strength (best first)."
  echo "If it is sucessfull the first connection is preserved till the DNS resolving and the test"
  echo "downloads fail or after a \"touch /var/tmp/next_wifi_please\"."
  echo
  echo "  $0 0"
  echo
  echo "does only scanning."
  echo
  echo "  $0 2 Telekom"
  echo
  echo "does try to connect open WiFis if their name/ESSID is NOT \"Telekom\"."
  echo
  echo "  $0 3 example_ap"
  echo
  echo "does only try to connect to the open WiFi with the name/ESSID \"example_ap\"."
  if [[ ("$#" -gt 0) && ("--help" = "$1") ]]
  then
    exit 0
  else
    exit -1
  fi
fi

# Make sure the script is run as root because the routing, device handling etc. can not be done by a user.
#if [ $EUID -ne 0 ]
if [ $GROUPS -ne 0 ]
then
  echo "Error: This script must be run from group root, but your group is $GROUPS; exiting."
  exit 1
fi

# some global/export parameters for the wifiscan program
# Directory for wifiscan
WIFISCANDIR=/tmp/wifiscan

########## Lockfile Part #####################

typeset -i sleeptime="1"   # sleeptime for creating the lockfile
typeset -i retries="10"	   # default number of retries of creating the lockfile: 10, should be > locktimeout*sleeptime
typeset -i locktimeout="5" # default timeout : 5 s. The lockfile will be removed
# by force after locktimeout seconds have passed since the lock-
# file was last modified/created. Lockfile is clock skew immune.
lockdir="/var/tmp"      # directory for the lock file
# Eleminate the optional bash call with sed and get this process name from basename.
this_process="$(basename "$(ps -p $$ -o cmd= | sed 's/^[^ ]*bash //')")"
lockfile="$lockdir/.lockfile.$this_process" # (hidden) lockfile name
# remove parameters
lockfile="`echo "$lockfile" | cut -d" " -f1`"

# ascertain whether we have lockfile
check ()
{
  if [ -z "$(which lockfile | grep -v '^no ')" ] ; then
    echo "$0 failed: 'lockfile' utility not found in PATH. Please install the package procmail" >&2
    echo "or comment out the lockfile funktion in the main part of this script." >&2
    exit 1
  fi
}

# make lockifle
lock ()
{
  typeset -i pid=0
  # check if a lockfile is present
  if [ -f "$lockfile" ]
  then
    # check the PID in the lockfile
    pid="$(cat "$lockfile")"
    if [ $pid -eq 0 ]
    then
      echo "Could not read a valid PID from the lockfile."
      echo "Trying to remove that lockfile"
      echo "$lockfile"
      echo "."
      rm -f "$lockfile"
    else
      if kill -0 $pid 2> /dev/null; then
        echo "The locking executable with pid $pid and lockfile  \""$lockfile"\" appears to be already running."
        # check if the process with the found UID
        if [ $(ps -p $pid -o uid=) == $UID ] ; then
          echo "The locking process has been created from the same user $UID which is running this script; exiting."
          exit 1
        else
          echo "The locking process has been created from the different user"
          echo $(ps -p $pid -o uid=)
          echo "; the user (UID) of this script is $UID."
          # If you want to (try to) kill the blocking process, uncomment the following 3 lines.
          echo "Try to kill this locking process."
          kill -9 $pid
          rm -f "$lockfile"
          echo "Done killing and lockfile deletion."
          # Maybe in the line before the next fi you should send an email to root@localhost that a user tried (or maybe caused)
          # a DOS attack and that the blocking process (here undocumented because already killed) was killed.
        fi
      else
        echo "The locking executable with pid $pid has completed or was killed without cleaning up its lockfile"
        echo "or the locking executable has another name than this script or it is run by an other user;"
        echo "removing that lockfile"
        echo "$lockfile"
        echo "."
        rm -f "$lockfile"
      fi
    fi
  else
    echo "No old lock file found (ok)."
  fi
  # (try to) create the lockfile; wait
  if ! lockfile -$sleeptime -r $retries -l $locktimeout "$lockfile" 2> /dev/null; then
    echo "$0: Failed: Couldn't create lockfile in time, exiting" >&2
    exit 1
  fi
  chmod u+rw "$lockfile"
  # store the pid
  echo $$ > "$lockfile"
  chmod u-wx "$lockfile"
  # A trap to delete the lockfile when the script gets killed by SIGHUP SIGINT or SIGTERM.
  # In many cases, e. g. a kernel hangup, this does not work and the checks above are necessary.
  #trap "rm -f $lockfile; exit" SIGHUP SIGINT SIGTERM
}

# cleanup
unlock ()
{
  rm -f "$lockfile"
}

#################### "main" part ##############################

# array of 6 MAC Bytes
declare -a MACBYTE

# array of 6 MAC Bytes as strings
declare -a MACBYTESTRING

# set the current MAC, stored in the MACBYTE array
setmac ()
{
  typeset -i i=0
  
  # Shut down and clear arp cache and ip(s) for the device, to avoid zombie entries.
  ip link set dev "$DEVICE" down
  ip neigh flush dev "$DEVICE"
  ip addr flush dev "$DEVICE"
  
  # put the MAC bytes together
  for ((i=0; i<=5; i++)) # for every byte: int to string
  do
    printf -v MACBYTESTRING[$i] "%x" ${MACBYTE[$i]}
  done
  MAC=${MACBYTESTRING[5]}:${MACBYTESTRING[4]}:${MACBYTESTRING[3]}:${MACBYTESTRING[2]}:${MACBYTESTRING[1]}:${MACBYTESTRING[0]}
  ip link set dev "$DEVICE" address $MAC
}

# Set a new random mac by toggling the bits of one bit group, set the new MAC, toggling the next and so on.
# After each toggling the new MAC is set and active if the MAC is valid. If not, the last valid MAC is
# active. At least the MAC after the first toggling should be valid.
# The function starts with the permanent MAC to assure that the random new MAC is different from the permanent.
# Otherwise the result would be that sometimes the random MAC is equal to the permanent MAC.
togglemacbitsgroups ()
{
  typeset -i i=0
  typeset -i j=0
  typeset -i x=0
  
  # Get the current MAC as string.
  #MAC=`ifconfig "$DEVICE" | grep Ethernet | awk '{print $NF}'`
  N=2
  MAC=`ifconfig "$DEVICE" | grep Ethernet | awk -v N=$N '{print $N}'`
  echo -e "Device $DEVICE:\tOld MAC = $MAC"
  
  # Set the permanent MAC
  {
    macchanger -p "$DEVICE"
  }>/dev/null
  
  # Get the permanent MAC as string.
  #MAC=`ifconfig "$DEVICE" | grep Ethernet | awk '{print $NF}'`
  N=2
  MAC=`ifconfig "$DEVICE" | grep Ethernet | awk -v N=$N '{print $N}'`
  echo -e "          permanent MAC = $MAC"
  
  # get the six bytes of the MAC
  for ((i=1; i<=6; i++))
  do
    # field of the MAC: field number 1 is byte5, 6 byte0
    j=6-$i
    BYTESTRING=`echo $MAC | cut -d":" -f$i`
    MACBYTE[$j]=$((0x$BYTESTRING))
  done
  
  # First bit group: Random toggle the last 3 bits, at least one.
  x=$(($RANDOM % 7 +1))
  let MACBYTE[0]^=$x
  
  # Set the new MAC. The first setting should be valid, so no ignoring of error messages.
  setmac
  
  # Second bit group: Random toggle bit3 ... bit7, at least one.
  x=$(($RANDOM % 32 +1))
  let 'x<<=3'
  let MACBYTE[0]^=$x
  # Set the new MAC
  {
    setmac  2>&1 >/dev/null
  }>/dev/null
  
  # Random toggle the bits in every remaining byte, at least one per byte
  for ((i=1; i<=5; i++))
  do
    x=$(($RANDOM % 255 +1))
    let MACBYTE[i]^=$x
    {
      setmac  2>&1 >/dev/null
    }>/dev/null
  done
  
  # MAC=`ifconfig "$DEVICE" | grep Ethernet | awk '{print $NF}'`
  N=2
  MAC=`ifconfig "$DEVICE" | grep Ethernet | awk -v N=$N '{print $N}'`
  echo -n -e "             \tnew MAC = $MAC"
  
  # MAC: Strip all punctuation; convert to uppercase; rewrite
  OUI="$(sed -ne '{s/[\.:\-]//g;s/[a-f]/\u&/g;s/^\([0-9A-F]\{2\}\)\([0-9A-F]\{2\}\)\([0-9A-F]\{2\}\).*/\1\2\3/p}' <<< $MAC)"
  # get the MAC vendor
  ACTVENDOR=\""`cat "$OUITXT" | grep "$OUI" | sed -e 's/^.\{,7\}//'`"\"
  echo " $ACTVENDOR"
  
} # togglemacbitsgroups


# function to (re-)init the WiFi device and randomize the MAC
randomizemac ()
{
  # shut down
  ifconfig "$DEVICE" down
  #iwconfig "$DEVICE" txpower off
  
  # Preparation: Set mode monitor because since 2013-11 the MAC can not be changed in mode managed!
  #iwconfig "$DEVICE" mode Monitor
  
  # Since 2013-11 the ifconfig fails (error "SIOCSIFHWADDR: Invalid argument"), but macchanger still works.
  # so the iwconfig version is commented below the macchanger version.
  # Set random vendor MAC of any kind.
  #echo "At device "$DEVICE":"
  #macchanger -A "$DEVICE"
  # store the MAC in global variable $MAC.
  #MAC="`ifconfig "$DEVICE" | grep Ethernet | awk '{print $NF}'`"
  
  # Set a random MAC. Because modern WIFI cards usually have higher bytes (numbers), this ensures another and random MAC.
  #ran=$(head /dev/urandom | md5sum)
  #MAC=00:0$[$RANDOM%6]:${ran:0:2}:${ran:3:2}:${ran:5:2}:${ran:7:2}
  #ifconfig "$DEVICE" hw ether "$MAC"
  #ip link set dev "$DEVICE" down
  #ip link set dev "$DEVICE" address "$MAC"
  
  #echo "switching MAC of $DEVICE to $MAC"
  
  ## set client mode (mode managed)
  iwconfig "$DEVICE" mode Managed
  
  # Set a random other MAC
  togglemacbitsgroups
  
  #ifconfig "$DEVICE" promisc
  #ifconfig "$DEVICE" -arp
  
  # disable the ESSID checking (ESSID promiscuous), set no key
  iwconfig "$DEVICE" channel auto
  iwconfig "$DEVICE" essid any
  iwconfig "$DEVICE" key off
  iwconfig "$DEVICE" frag auto
  
  # rts handshaking on, see e. g. https://en.wikipedia.org/wiki/File:RTS_CTS_benchmark.png
  iwconfig "$DEVICE" rts 1
  
  # increase the retry level
  iwconfig "$DEVICE" retry 30
  
  # uncomment the next line to disable power saving
  iw dev "$DEVICE" set power_save off
  # disable WiFi power management, for better stability
  iwconfig "$DEVICE" power off
  # start with default power
  iwconfig "$DEVICE" txpower auto
  # set the high power flag
  {
    iwpriv "$DEVICE" highpower 1 2>&1 > /dev/null
  } >>/dev/null
  
  # Set a trasmission power of $TXPOWER dBm.
  # The value set here should be (smaller than or) equal to the maximum of your adapter.
  #iwconfig "$DEVICE" txpower 500mW
  iwconfig "$DEVICE" txpower "$TXPOWER"
  iw dev "$DEVICE" set txpower fixed "$TXPOWER2"
  #iwconfig "$DEVICE" txpower on
  
  # make changes active
  {
    iwconfig "$DEVICE" commit 2>&1 >/dev/null
  } >>/dev/null
  
  # go online with the device
  ifconfig "$DEVICE" up
  
  # Set the bit rate: The lowest, 1M, for best stability. This must be done after the up, when the network is online.
  # You can add the "auto" option, which allows lower rates and should be usefull for rates higher 1 Mbit/s. But with the auto
  # option i have not seen more than 1 Mbit/s, so the options 1M and auto do the same. Other possible rates are
  # 2, 5.5, 6, 6.5, 9, 11, 12, 13, 18, 24, 36, 48, 54, 78, 81, 104, 108, 117, 121.5, 135, 150, 162, 216, 243, 270, 300,
  # 600 and higher, if the access point and you adapter can do it.
  # If the minimum rate with the assozicated AP is higher the rate gets automatically increased to that value.
  iwconfig "$DEVICE" rate auto #1M
} # randomizemac

# Kill the network manager; this script can use the WiFi devices only alone.
# If you can't connect and have a "Device or resource busy" error you should check
# the place of the network manager (locate -i network | grep -i manager | grep bin
# or locate -i network | grep -i manager | less) and update this function with an
# addtional block.
networkmanagerkill ()
{
  # Network Manager under Ubuntu (13.04)
  #nw_manager=/etc/init.d/network-manager
  #if  [ -e $nw_manager ]
  #then
  #  $nw_manager stop 2>&1 > /dev/null
  #fi
  
  # Network Manager under openSuSE (12.3)
  #nw_manager=/usr/sbin/NetworkManager
  #if  [ -e $nw_manager ]
  #then
  #  $nw_manager stop 2>&1 > /dev/null
  #fi
  
  { 
    /etc/init.d/network-manager stop 2>&1 > /dev/null
    killall NetworkManager 2>&1 > /dev/null
    killall -9 NetworkManager 2>&1 > /dev/null
    killall network-manager 2>&1 > /dev/null
    killall -9 network-manager 2>&1 > /dev/null
    killall modem-manager 2>&1 > /dev/null
    killall -9 modem-manager 2>&1 > /dev/null
    killall ModemManager 2>&1 > /dev/null
    killall -9 ModemManager 2>&1 > /dev/null
  } >>/dev/null
}

# function to kill the DHCP client(s) by command, pid files and killall
dhckill ()
{
  # dhclient part
  type -P dhclient > /dev/null
  if [ $? -eq 0 ]
  then
    if [ -z "`pgrep -x dhclient`" ]
    then
      : # dhclient is not running, ok, null command
    else
      {
        timeout 3 dhclient -r 2>&1 >/dev/null # release the current lease and exit
        rm -f /var/lib/dhcp*/dhclient.leases
        if [ -f /var/run/dhclient.pid ]
        then
          kill `cat /var/run/dhclient.pid` 2>&1 >/dev/null
        fi
        rm -f /var/run/dhclient.pid
        killall dhclient 2>&1 >/dev/null
      } >>/dev/null
    fi
  fi
  
  # dhcpcd part
  type -P dhcpcd > /dev/null
  if [ $? -eq 0 ]
  then
    if [ -z "`pgrep -x dhcpcd`" ]
    then
      : # dhcpcd is not running, ok, null command
    else
      {
        timeout 3 dhcpcd -k "$DEVICE" 2>&1 >/dev/null     # release the current lease, deconfigure the interface and exit
        if [ -f /var/run/dhcpcd-"$DEVICE".pid ]
        then
          kill `cat /var/run/dhcpcd-"$DEVICE".pid` 2>&1 > /dev/null
        fi
        rm -f /var/run/dhcpcd-"$DEVICE".pid
        killall dhcpcd 2>&1 >/dev/null
      } >>/dev/null
    fi
  fi
} # dhckill

# lockfile: first check, then lock
check
lock

# create temporary (hidden) working directory and change into that directory
#TMPDIR0="/tmp/.$0.$$.$RANDOM.DIR1.if.txt"
#mkdir "$TMPDIR0"
#TMPDIR0=`mktemp -d -p /tmp ."$RANDOM"_XXXXXX`
# Since 2013-11: Temporary files in the fast ramfs, not relative slow HDD/SSD, which should be given a break.
{
  umount "$WIFISCANDIR" 2>&1 >/dev/null
}>/dev/null
rm -rf "$WIFISCANDIR"
mkdir -p "$WIFISCANDIR"
mount -t ramfs -o maxsize=100m ramfs "$WIFISCANDIR"
TMPDIR0=$WIFISCANDIR/tmp
mkdir "$TMPDIR0"
cd "$TMPDIR0"

# bash trap function for cleanup at exit (executed e. g. when CTRL-C is pressed)
# Signals: 1/HUP, 2/INT, 3/QUIT, 9/KILL, 15/TERM, ERR, EXIT
trap bashtrap 2 9 15 EXIT
bashtrap()
{
  cd /tmp/
  sleep 0.5
  {
    umount -l "$WIFISCANDIR" 2>&1 >/dev/null
    umount -r "$WIFISCANDIR" 2>&1 >/dev/null
    umount -f "$WIFISCANDIR" 2>&1 >/dev/null
  }>/dev/null
  dhckill # terminate DHCP clean
  rm -f /var/lib/dhcp*/dhclient.leases
  rm -f /home/knoppix/Desktop/online
  rm -f /var/tmp/next_wifi_please
  #rm -rf "$TMPDIR0"
  unlock
  #echo "Signal: $(($?-128))"
  rm -rf "$WIFISCANDIR"
  exit 0
}

# create temporary files
#TMPFILE0="$TMPDIR0/.$0.$$.$RANDOM.0.if.txt"
#TMPFILE0=`tempfile -d "$TMPDIR0"` # tempfile is not part of the coreutils
TMPFILE0=`mktemp --tmpdir="$TMPDIR0" ."$RANDOM"_XXXXXX`
TMPFILE1=`mktemp --tmpdir="$TMPDIR0" ."$RANDOM"_XXXXXX`

# Delete proxy environment variables (for test downloads).
# Uncomment this section when you have to use a proxy (dual-homed bastion host configuration)
# and this proxy is already set.
unset proxy
export proxy
unset http_proxy
export http_proxy
unset https_proxy
export https_proxy
unset ftp_proxy
export ftp_proxy

# constants, parameters
# Deadline counter limit
declare -r DEADLINECOUNTERLIMIT=2
# ping count for testing the connection to the AP
declare -r PINGCOUNT=3
# MTU, common minimum value is 256, 512 a good medium value
declare -r MTU=512
# Transmission Power in dBm. 27 dBm = 500 mW is a good medium high value.
declare -r TXPOWER=27
# Transmission Power in mBm, which is hundred times the power in dBm.
typeset -i TXPOWER2=$(($TXPOWER*100))

# the MAC vendor list, from package arp-scan
OUITXT='/usr/share/arp-scan/ieee-oui.txt' #'/usr/share/oui.txt'

# variables for open WIFI count (0...), etc.
typeset -i OPENCOUNT=0
typeset -i CLOSEDCOUNT=0
typeset -i CELLCOUNT=0
typeset -i i=1
typeset -i j=0
typeset -i k=0
typeset -i l=0
typeset -i m=0
typeset -i pi=0
typeset -i pj=0
typeset -i device_counter=0
declare -a APMAC
declare -a OPENCELLNUMBER
declare -a CHANNEL
declare -a ESSID
typeset -i deadline_counter=0
typeset -i loop_counter=0
typeset -i connected=0 # flag: 0 if offline, 1 if online (dns lookup and file download worked)
# if set, the online icon is on the Desktop
typeset -i flag=0
typeset -i SCANNUMBER=0
typeset -i counter0=0
typeset -i counter1=0
typeset -i devicecount=0
typeset -i maccount=0
typeset -i online_loop_counter=0 # the approx. online time in s is this times 10
# array of devices
declare -a DEVS

# array of actual (SW) MACs
declare -a MACS

# start of the endless loop with scanning, looking for open WIFIs, testing/using
while true
do
  # Set country code / region code NZ (New Zealand) for Channel 1-13 and 1000 mW maximum TxPower in
  # the 2.4 GHz band and not few channels in the 5 GHz band. Get the list of countries with what
  # they allow via regdbdump /lib/crda/regulatory.bin or /lib/crda/regulatory.bin.
  # For Channels 1-14 (in the 2.4 GHz band) and 100 mW maximum Power, set JP (Japan).
  # If you want more or less channels or more or less maximum power, add an apropriate region to the
  # Regulatory database and an use it. See e. g.
  # http://deckardt.nl/blog/2011/01/20/regulatory-limitations-in-linux-wireless/
  REGDOMAIN=DI
  iw reg set $REGDOMAIN
  echo "Region Domain $REGDOMAIN is set"
  
  # soft switch on WiFi devices
  rfkill unblock wifi
  
  # kill other stuff which uses the device(s)
  networkmanagerkill #2>&1 2> /dev/null &
  
  # Uncomment the next 2 code (echo... and modprobe...) lines to remove the driver of the integrated weak wifi device
  # (in my first laptop with driver rtl8187, in my second iwlwifi) to speed up the script.
  # You can find the loaded wifi driver(s) via hwinfo --wlan | grep -i "driver modules:"
  #modprobe -r rtl8187 2> /dev/null  #rmmod rtl8187 2> /dev/null
  echo "Unloading unnecessary modules ..."
#modprobe -r iwldvm 2> /dev/null; modprobe -r iwlwifi 2> /dev/null
  
  # Display the status not connected now for Knoppix Desktop
  rm -f /home/knoppix/Desktop/online
  online_loop_counter=0
  connected=0
  
  # number of WiFi devices
  devicecount=`iwconfig 2> /dev/null | grep "wl" | wc -l`
  
  if [ $devicecount -ge 1 ]
  then
    echo -n "List of $devicecount availible WIFI device(s):"
    #iwconfig 2> /dev/null | grep "ESSID" | cut -d" " -f1
    #iwconfig 2> /dev/null | grep "wl" | cut -d" " -f1
    #tail -n +3 /proc/net/wireless
  else
    echo "No WiFi device found."
    sleep 1 # wait a second for a WiFi device
    continue; # no wifi device, goto start
  fi
  
  # scan for WIFI = wlan devices
  i=1
  iwconfig  2>&1 | grep "wl" > xx1
  while read line
  do
    DEVS[$i]=`echo $line | cut -d" " -f1`
    echo -n " ${DEVS[$i]}"
    # set offline for configuration
    ifconfig ${DEVS[$i]} down
    i=$[$i +1]
  done <xx1
  echo
  # now the devices are at ${DEVS[1]} ... ${DEVS[$devicecount]} and down
  #for device_counter in $(seq 1 "$devicecount")
  for ((device_counter=1; device_counter<=devicecount; device_counter++))
  do
    DEVICE=${DEVS[$device_counter]}
    OPENCOUNT=0
    
    # make sure not dhcp is blocking
    dhckill
    #dhckill 2>&1 2> /dev/null &
    
    # not connected now
    rm -f /home/knoppix/Desktop/online
    online_loop_counter=0
    connected=0
    
    
    # Change the MAC before every scan to a random and valid OTHER MAC, and not equal to an actual MAC.
    # Get all MACs, the HW MAC(s) and the actual (SW) MAC(s).
    #i=1
    #hwinfo --wlan | grep HW > xx1
    #while read line
    #do
    #  MACS[$i]=`echo $line | cut -d" " -f3`
    #  echo "MAC: ${MACS[$i]}"
    #  i=$[$i +1]
    #done <xx1
    
    # get the MACs, insert "| tee /dev/stderr" for debugging
    ifconfig -a | grep Ethernet | awk '{print $NF}' > xx1
    maccount=`cat xx1 | wc -l`
    
    # put the MACs into the array
    i=1
    while read line
    do
      MACS[$i]="$line"
      #echo "Actual own MAC: ${MACS[$i]}"
      i=$[$i +1]
    done <xx1
    # now the MACs are at ${MACS[1]} ... ${MACS[$maccount]}
    
    #/usr/bin/shred -f -x --iterations=1 --remove xx1
    rm -f xx1
    
    # set a random OTHER MAC
    flag=0
    while [ $flag -eq 0 ]
    do
      randomizemac
      # Get the actual MAC string.
      #MAC=`ifconfig "$DEVICE" | grep Ethernet | awk '{print $NF}'`
      N=2
      MAC=`ifconfig "$DEVICE" | grep Ethernet | awk -v N=$N '{print $N}'`
      # check the actual MAC $MAC
      flag=1 # the whole MAC check is passed when no single MAC check failes
      #for i in $(seq 1 "$maccount")
      for ((i=1; i<=maccount; i++))
      do
        if [ "$MAC" = "${MACS[$i]}" ]
        then # the new MAC is equal to a used MAC
          flag=0           # Abandon the loop over the used MACs.
          echo "The current MAC is not new, so a new one is needed."
          break
        fi
      done
    done
    # Now we have a new random and unique MAC (or an infinite loop with error messages when the MAC can't be
    # changed).
    
    # scan and get a list of (open) wifi points
    echo "Scan number $SCANNUMBER, scanning ..................................................................."
    SCANNUMBER=$[$SCANNUMBER +1]
    # iwlist uses a kernel interface which can list only up to 64 WiFis, but usually this is enough.
    # Kismet or Aircrack-ng would be better.
    iwlist "$DEVICE" scanning > "$TMPFILE0" 2>/dev/null
    
    # remove the first line of the scan output (with "Scan completed")
    i=`wc -l < "$TMPFILE0"`
    i=$[$i -1]
    tail -n $i "$TMPFILE0" > "$TMPFILE1"
    
    # get the number of open WIFIs
    cat "$TMPFILE1" | grep "Encryption key:off" > "$TMPFILE0"
    OPENCOUNT=`wc -l < "$TMPFILE0"`
    
    # get the number of closed WIFIs
    cat "$TMPFILE1" | grep "Encryption key:on" > "$TMPFILE0"
    CLOSEDCOUNT=`wc -l < "$TMPFILE0"`
    
    echo "Found $OPENCOUNT open WIFI(s) and $CLOSEDCOUNT closed WIFI(s)."
    
    # get the total number of WIFIs (Cells)
    cat "$TMPFILE1" | grep "Encryption key:" > "$TMPFILE0"
    CELLCOUNT=`wc -l < "$TMPFILE0"`
    
    # Split the scan output into one file per cell; the files are , xx2, ...
    #csplit --digits=1 -k "$TMPFILE1" '/Cell/' {*} 2> /dev/null > /dev/null
    csplit --digits=1 -k "$TMPFILE1" '/ Cell [0-9][0-9]* - Address: [A-Fa-f0-9][A-Fa-f0-9]:[A-Fa-f0-9][A-Fa-f0-9]:[A-Fa-f0-9][A-Fa-f0-9]:[A-Fa-f0-9][A-Fa-f0-9]:[A-Fa-f0-9][A-Fa-f0-9]/' {*} 2>&1 >/dev/null
    
    # print the WIFI data
    
    if [ $CELLCOUNT -ge 0 ]
    then
      echo "List of WIFI(s) with Channel, Encryption, Quality, Signal Level, MAC, ESSID. Vendor:"
      i=1 # number for the first WIFI MAC
      #for loop_counter in $(seq 1 "$CELLCOUNT")
      for ((loop_counter=1; loop_counter<=CELLCOUNT; loop_counter++))
      do
        # command line output
        #ACTCHANNEL="`cat xx$loop_counter | awk '/Channel:/{ print $1 }'`"
        #ACTCHANNEL="`cat xx$loop_counter | grep -i "channel " | cut -d"l" -f2 | sed 's/.$//'`"
        ACTCHANNEL="`cat xx$loop_counter | grep -i channel: | cut -d":" -f2`"
        echo -n "$ACTCHANNEL"
        ACTENCRYPTION="`cat xx$loop_counter | awk '/Encryption/{ print $2 }' | cut -d":" -f2`"
        echo -n -e "\t$ACTENCRYPTION"
        ACTQUALITY="`cat xx$loop_counter | awk '/Quality/{ print $1}' | cut -d"=" -f2`"
        echo -n -e "\t$ACTQUALITY"
        #ACTSIGNALLEVEL="`cat xx$loop_counter | awk '/Quality/{ print $3}'`"
        ACTSIGNALLEVEL="`cat xx$loop_counter  | grep -i level | cut -d"=" -f3 | cut -d" " -f1`"
        echo -n -e "\t$ACTSIGNALLEVEL"
        ACTMAC="`cat xx$loop_counter | awk '/Address/{ print $5 }'`"
        echo -n -e "\t$ACTMAC  "
        #ACTESSID="`cat xx$loop_counter | grep ESSID | cut -d":" -f2`" # awk '/ESSID/{ print $1 }'`"
        # get the ESSID with the quotation marks
        ACTESSID=`cat xx$loop_counter | grep ESSID | cut -d ":" -f 2- | cut -c 1-129`
        #echo -n "$ACTESSID "
        # MAC: Strip all punctuation; convert to uppercase; rewrite
        OUI="$(sed -ne '{s/[\.:\-]//g;s/[a-f]/\u&/g;s/^\([0-9A-F]\{2\}\)\([0-9A-F]\{2\}\)\([0-9A-F]\{2\}\).*/\1\2\3/p}' <<< $ACTMAC)"
        # get the MAC vendor
        ACTVENDOR=\""`cat "$OUITXT" | grep "$OUI" | sed -e 's/^.\{,7\}//'`"\"
        #echo "$ACTVENDOR"
        printf "%-30s %-30s\n" "$ACTESSID" "$ACTVENDOR"
        # output for wifiscan. Start with the file name <mac>,<channel>,<plain_hexdump(ESSID)>.<mseconds>
        ACTESSIDBASE=`echo -n $ACTESSID | xxd -p`
        ACTTIMEMS=$(($(date +%s%N)/1000000))
        ACTCHANNELNR="`echo "$ACTCHANNEL" | cut -d":" -f2`" # strip "Channel:"
        ACTQUALITYS="`echo "$ACTQUALITY" | cut -d"=" -f2`" # strip "Channel: # strip "Quality="
        ACTSIGNALLEVELS="`echo "$ACTSIGNALLEVEL" | cut -d"=" -f2`"  #strip "level="
        ACTFILENAME="$WIFISCANDIR"/"$ACTMAC","$ACTCHANNELNR","$ACTESSIDBASE"."$ACTTIMEMS"
        # store the data as CSV
        echo -n "$ACTCHANNELNR " > "$ACTFILENAME"
        echo -n "$ACTENCRYPTION " >> "$ACTFILENAME"
        echo -n "$ACTQUALITYS " >> "$ACTFILENAME"
        echo -n "$ACTSIGNALLEVELS " >> "$ACTFILENAME"
        echo -n "$ACTMAC " >> "$ACTFILENAME"
        echo -n "$ACTTIMEMS " >> "$ACTFILENAME"
        echo -n "$ACTESSID" >> "$ACTFILENAME"
        #echo -n "$ACTVENDOR" >> "$ACTFILENAME"
      done
    fi
    
    # cleanup: delete temporary wifiscan files older than one minute
    find "$WIFISCANDIR" -mmin +1 -type f -exec rm {} \;
    
    # if no open WIFI found: continue (go to next device and make a new scan)
    if [ $OPENCOUNT -eq 0 ]
    then
      #ifconfig $DEVICE down
      continue
    fi
    
    # Now we have at minimum one open WIFI.
    # Create the list of open WIFIs (OPENCELLNUMBER[1]...OPENCELLNUMBER[$OPENCOUNT])
    #i=1 # first number of the first open WIFI
    #for loop_counter in $(seq 1 "$CELLCOUNT")
    for ((loop_counter=1; loop_counter<=CELLCOUNT; loop_counter++))
    do
      cat xx$loop_counter | grep "Encryption key:off" 2>&1 >/dev/null
      if [ $? -eq 0 ]
      then
        OPENCELLNUMBER[$i]=$loop_counter
        i=$[$i +1]
      fi
    done
    
    # Sort the list of open WiFis by quality: highest/best first.
    # With really lots of open WIFIs (several thousands) you may should use something really faster,
    # like GPU-Quicksort or GPUSort.
    # tmpfiles for sorting
    TMPFILE2=`mktemp --tmpdir="$TMPDIR0" ."$RANDOM"_XXXXXX`
    TMPFILE3=`mktemp --tmpdir="$TMPDIR0" ."$RANDOM"_XXXXXX`
    # Write the quality and OPENCELLNUMBER to tmpfile2
    #for i in $(seq 1 "$OPENCOUNT")
    for ((i=1; i<=OPENCOUNT; i++))
    do
      l=${OPENCELLNUMBER[$i]}
      # get quality
      #qi=`cat xx$l | awk '/Quality/{ print $1}' | cut -d"=" -f2 | cut -d"/" -f1 | cut -d":" -f2`
      # get the absolute value of the level
      qi=`cat xx$l | awk '/level=/{ print $3}'  | cut -d"=" -f2 | cut -d"-" -f2`
      echo "$qi $l" >> "$TMPFILE2"
    done
    
    # sort via sort: higher quality is better
    #sort -n -r --temporary-directory="$TMPDIR0" "$TMPFILE2" -o "$TMPFILE3"
    # sort via sort: lower absolute value is better
    sort -n --temporary-directory="$TMPDIR0" "$TMPFILE2" -o "$TMPFILE3"
    
    # read the sorted list
    i=1
    while read line
    do
      OPENCELLNUMBER[$i]=`echo $line | cut -d" " -f2`
      i=$[$i +1]
    done <"$TMPFILE3"
    
    # Print the sortet list of open WiFis
    if [ $OPENCOUNT -ge 1 ]
    then
      echo "Sorted list of $OPENCOUNT free WIFI(s):"
      #for i in $(seq 1 "$[$OPENCOUNT]")
      for ((i=1; i<=OPENCOUNT; i++))
      do
        echo -n "`cat xx${OPENCELLNUMBER[$i]} | awk '/Channel:/{ print $1 }'`"
        echo -n -e "\t`cat xx${OPENCELLNUMBER[$i]} | awk '/Encryption/{ print $2 }' | cut -d":" -f2`"
        echo -n -e "\t`cat xx${OPENCELLNUMBER[$i]} | awk '/Quality/{ print $1}'` "
        echo -n -e "\t`cat xx${OPENCELLNUMBER[$i]} | awk '/Quality/{ print $3}'` "
        echo -n -e "\t`cat xx${OPENCELLNUMBER[$i]} | awk '/Address/{ print $5 }'`"
        echo " `cat xx${OPENCELLNUMBER[$i]} | grep ESSID | cut -d ":" -f 2- `" # awk '/ESSID/{ print $1 }'`"
      done
    fi
    
    #echo "Sorted list of $OPENCOUNT free WIFI numbers:"
    #for i in $(seq 1 "$[$OPENCOUNT]")
    #do
    #  echo -n "${OPENCELLNUMBER[$i]}"
    #done
    
    # Now the strongest WIFI is at OPENCELLNUMBER[1], the weakest at OPENCELLNUMBER[$OPENCOUNT]
    # put the data of the open WIFIs into arrays
    #for i in $(seq 1 "$OPENCOUNT")
    for ((i=1; i<=OPENCOUNT; i++))
    do
      l=${OPENCELLNUMBER[$i]}
      APMAC[$i]=`cat xx$l | awk '/Address/{ print $5 }'`
      CHANNEL[$i]=`cat xx$l | awk '/Channel:/{ print $1 }' | cut -d ":" -f 2`
      foo=`cat xx$l | grep ESSID | cut -d ":" -f 2- | cut -c 2-129`
      ESSID[$i]="${foo%?}"
    done
    # now the MACs of the open WIFIs are at APMAC[1]...APMAC[$OPENCOUNT]
    
    # Check the first parameter: Try to connect only if there is none or if it is greater zero
    if [ "$#" -eq 0  ] || [ "$#" -gt 0 -a "$1" -gt 0 ]
    then
      # Check/use the list of open WIFI(s)
      #for loop_counter in $(seq 1 "$OPENCOUNT")
      for ((loop_counter=1; loop_counter<=OPENCOUNT; loop_counter++))
      do
        # If the number of parameters is 2: Filter due to ESSID, do not filter at 0 parameters or first parameter 1.
        # $1 == 2 : !=, do NOT connect to the ESSID ($2) or $1 == 3 : ==, do connect to the ESSID ($2)
        if [[ ("$#" -eq 0) || ("$#" -gt 0) && ("$1" -eq 1) || ("$#" -eq 2) && ( ( ("$1" -eq 2) && ("$2" != "${ESSID[$loop_counter]}") ) || ( (("$1" -eq 3) || ("$1" -eq 4) || ("$1" -eq 5)) && ("$2" = "${ESSID[$loop_counter]}") ) ) ]]
        then
          deadline_counter=0
          rm -f /home/knoppix/Desktop/online
          online_loop_counter=0
          connected=0
          
          echo "Checking the open WIFI with MAC "${APMAC[$loop_counter]}", Channel "${CHANNEL[$loop_counter]}", ESSID "${ESSID[$loop_counter]}""
          while [ $deadline_counter -lt $DEADLINECOUNTERLIMIT ]  # give a connection try at minimum two $DEADLINECOUNTERLIMIT; the deadline is $DEADLINECOUNTERLIMIT
          do
            if  [[ (-f /var/tmp/next_wifi_please)  ||  ($connected -eq 0) ]]  # if cycling to next WIFI is forced or we are not connected
            then
              
              # kill the now outdated dhcp client
              dhckill
              
              # if necessary: go to next wifi
              if [ -f /var/tmp/next_wifi_please ]
              then
                rm -f /var/tmp/next_wifi_please
                break # leave the current WIFI and go to next
              fi
              
              # Set the parameters for the AP. IMPORTANT: Since the End of 2012 the iwconfig and iw command can not set the channel
              # or frequency and this gives an mysterious "device or resource busy" error. This caused the subsequent error that NO
              # parameter is set. So the commands with the frequency or channel are commented out, and DHCP can choose the wrong
              # channel.
              #iwconfig "$DEVICE" mode Managed ap "${APMAC[$loop_counter]}" channel "${CHANNEL[$loop_counter]}" essid "${ESSID[$loop_counter]}"
              iwconfig "$DEVICE" mode managed ap "${APMAC[$loop_counter]}" essid "${ESSID[$loop_counter]}"
              # iwconfig commit
              
              ifconfig "$DEVICE" up
              # Set the lowest bandwidth for lowest noise.
              #iw dev "$DEVICE" set channel "${CHANNEL[$loop_counter]}" HT20
              
              # DHCP configuration: use dhclient if availible, dhcpcd else
              #if command -s -v dhclient
              type -P dhclient > /dev/null
              if [ $? -eq 0 ]
              then # dhclient with makes only one try to get a lease, 5 s timeout
                timeout 3 dhclient -r "$DEVICE" # releases current configuration for the interface
                timeout 5 dhclient -1 "$DEVICE"
              else # dhcpcd with 5 s timeout (default is 60, but usually it takes less than 5), -A for don't request or claim the address by ARP, faster.
                #dhcpcd -A -t 5 "$DEVICE"
                #dhcpcd --noarp --noipv4ll -t 5 "$DEVICE"
                dhcpcd --noipv4ll -t 5 "$DEVICE"
              fi
              
              # Check if we can be connectet: Because dhclient always returns 0 (without option -1), check if we got an ip
              ifconfig "$DEVICE" | grep "inet "
              if [ $? -ne 0 ]
              then
                echo "DHCP got no ip."
                # set no IP
                ifconfig "$DEVICE" 0.0.0.0
                deadline_counter=$[$deadline_counter +1]
                connected=0
                rm -f /home/knoppix/Desktop/online
                online_loop_counter=0
                continue
              fi
              
              # set the MTU again because the DHCP client usually changes the MTU to 576
              # For weak connections with high packet loss: Set the MTU to twice the minimum value (256).
              # You can increase the value during a connection via command line (up to 1500)
              # to speed up a strong connection. For weak connections maybe setting the common minimum
              # value (256) may help.
              ifconfig "$DEVICE" mtu $MTU
              
            fi
            
            # now we are connected (to the AP) and we have an IP; we may be online
            echo
            echo "Connectet: "
            ifconfig "$DEVICE"
            iw dev "$DEVICE" station dump
            iwconfig "$DEVICE"
            cat /proc/net/wireless
            
            # check the internet connection by checking the IP, DNS lookups, test downloads
            counter0=0 # reset success counter
            
            # Chech for IPV4LL address 169.254.*.*
            tmp_string=`ifconfig "$DEVICE" | grep ":169.254."`
            if [ -z "$tmp_string" ]
            then # empty string, no IPV4ALL address, success!
              
              # if only pingging to the AP has to be tested, with ICMP or ARP, if mode 4 or 5
              if [[ ("$#" -gt 0) && ( ("$1" -eq 4) || ("$1" -eq 5) ) ]]
              then
                # reduce n empty spaces to one, get the second string of the route line with default
                AP=`route | grep default | tr -s " " | cut -d" " -f2`
                
                if [ "$AP" == "0" ] # the AP IP could not be found
                then
                  counter0=0;
                  echo "The AP could not be found."
                else
                  echo "AP IP:" "$AP"
                  DOSTRING=do # workaround for a beautify_bash bug which does not accept a simple "do"
                  # Check connection with ping to the access point
                  for ((i=0; i<$PINGCOUNT; i++))
                  do
                    {
                      # Usually use an ICMP Ping, if that does not work use an Arping (second case)
                      if [[ ("$#" -gt 0) && ("$1" -eq 4) ]] # if mode 4
                      then
                        ping -M $DOSTRING -Q 0x02  -q -w 3 -W 3 -c 1 -s 24 -p 0f1e2d3c4b5a6978 -n $AP
                      fi
                      if [[ ("$#" -gt 0) && ("$1" -eq 5) ]] # if mode 5
                      then
                        arping -c 1 -I "$DEVICE" $AP
                      fi
                    }&> /dev/null
                    if [ $? -eq 0 ] # if success
                    then
                      counter0=$[$counter0 +1]
                    fi
                  done
                  echo "Test pings: $counter0/$PINGCOUNT to $AP successfull."
                fi # if AP
                
              else # if ping test (to the AP), mode 4
                
                # DNS lookup for DNS root nameserver D
                foo=`dig -p 53 +time=2 -4 +short +noidentify terp.umd.edu`
                if  [ "$foo" == "192.186.200.199" ]
                then
                  counter0=$[$counter0 +1]  # ok counting
                  echo "  DNS lookup: terp.umd.edu found correct"
                fi
                
                # DNS lookup for dns.msftncsi.com, see http://technet.microsoft.com/en-us/library/cc766017%28WS.10%29.aspx
                foo=`dig -p 53 +time=2 -4 +short +noidentify dns.msftncsi.com`
                if  [ "$foo" == "131.107.255.255" ]
                then
                  counter0=$[$counter0 +1]
                  echo "  DNS lookup: dns.msftncsi.com found correct"
                fi
                echo "DNS lookup check: $counter0 DNS lookup(s) successfull."
                
              fi # if ping test, mode 4 or 5
              
            else
              echo "Got IPV4LL address, retrying"
            fi # IPV4LL
            
            if [[ ($counter0 -ne 0)  ||  ($connected -ne 0) ]]  # at minimum one DNS lookup/ping was successfull or we were online before; we may be online/connectet
            then
              counter1=0 # reset download check counter
              
              if [[ ("$#" -gt 0) && ( ("$1" -eq 4) || ("$1" -eq 5) ) ]] # if only pingging to the AP has to be tested (mode 4) or less than pinging (mode 5)
              then
                if [ $counter0 -eq 0 ] # if all pings failed
                then
                  counter1=2; # set code for no ping or DNS lookup was successfull
                fi
              else
                # test download section
                USER_AGENT=Mozilla/4.0\ \(compatible\;\ MSIE\ 7.0\;\ Windows\ NT\ 6.0\;\ SLCC1\;\ .NET\ CLR\ 2.0.50727\;\ .NET\ CLR\ 3.0.04506\)
                # Download the small google logo, with timeout command because even with --tries 1 wget does 6 tries!
                rm -f file
                timeout 4 wget -np --timeout=3 --tries=1 --user-agent="$USER_AGENT" --header="Accept-Encoding: deflate, gzip" --output-document=file http://www.google.com/images/logo_sm.gif 2>/dev/null
                # check the download sha1 sum
                echo "8cdaafa38904b78a5a3607d47bd12391dc99ecb4  file" > file.sha1
                sha1sum -c file.sha1 2>/dev/null
                counter1=$[$counter1 +$?] # error counting
                
                # download the SM test file
                rm -f file
                #wget -np --proxy=off --timeout=5 --tries=1 --user-agent="$USER_AGENT" --header="Accept-Encoding: deflate, gzip" --output-document=file http://www.msftncsi.com/ncsi.txt 2>/dev/null
                timeout 4 wget -np --timeout=3 --tries=1 --user-agent="$USER_AGENT" --header="Accept-Encoding: deflate, gzip" --output-document=file http://i.microsoft.com/global/en/publishingimages/sitebrand/microsoft.gif 2>/dev/null
                # check the download
                #echo "33bf88d5b82df3723d5863c7d23445e345828904  file" > file.sha1
                echo "53941316e946bc0b4fe940ff6364cc560cf5eb4a  file" > file.sha1
                sha1sum -c file.sha1 2>/dev/null
                counter1=$[$counter1 +$?] # error counting
              fi # if ping test or less (mode 4 or 5)
              
              if [ $deadline_counter -gt 0 ] # if deadline counting started
              then
                echo "deadline_counter: $deadline_counter (limit $DEADLINECOUNTERLIMIT)"
              fi
              if [ $counter1 -ge 2 ]  # all test downloads or pings failed
              then
                if [[ ("$#" -gt 0) && ("$1" -ne 4) ]]
                then
                  echo "all test downloads failed"
                else
                  echo "all pings failed"
                fi
                # increase the deadline counter if we were not connected before or
                # if we were connected but also all DNS lookups failed
                if [ $connected -eq 0 ] # not connected before
                then
                  deadline_counter=$[$deadline_counter +1]
                else
                  if [ $counter0 -eq 0 ]
                  then
                    deadline_counter=$[$deadline_counter +1]
                    #else # at minimum one dns lookup was successfull; we are half online
                    #sleep 1 # wait a second before the next checks
                  fi
                fi
              else
                if [[ ("$#" -gt 0) && ("$1" -ne 4) ]]
                then
                  # At minimum one download was successfull, we are online. Wait ten seconds before the next connection check.
                  echo -n "External IP: "
                  #curl --connect-timeout 3 -m 5 ifconfig.me # too slow 2013-09
                  curl --connect-timeout 3 -m 5 ip.appspot.com
                  #curl --connect-timeout 3 -m 5 -s http://checkip.dyndns.org/ | grep -o "[[:digit:].]\+"
                  #curl --connect-timeout 3 -m 5 ipecho.net/plain; echo
                  #lynx --dump http://ipecho.net/plain
                  {
                    touch /home/knoppix/Desktop/online 2>&1 >/dev/null
                  }>/dev/null
                  echo "Online! online_loop_counter=$online_loop_counter"
                fi
                deadline_counter=0
                connected=1
                online_loop_counter=$[$online_loop_counter +1]
                # show the link status: AP-MAC, SSID, freq., RX, TX, RX signal, TX bitrate
                iw dev "$DEVICE" link
                #for i in $(seq 1 10)
                for ((j=1; j<=1; j++))
                do
                  #iwconfig "$DEVICE" > $TMPFILE0
                  
                  # scan and get a list of (open) wifi points
                  echo "Scan number $SCANNUMBER, scanning and printing details in background (/tmp)"
                  SCANNUMBER=$[$SCANNUMBER +1]
                  TMPFILE0=`mktemp --tmpdir="$TMPDIR0" ."$RANDOM"_XXXXXX`
                  iwlist "$DEVICE" scanning > "$TMPFILE0" 2>/dev/null
                  
                  # remove the first line of the scan output (with "Scan completed")
                  i=`wc -l < "$TMPFILE0"`
                  i=$[$i -1]
                  tail -n $i "$TMPFILE0" > "$TMPFILE1"
                  
                  # get the number of open WIFIs
                  cat "$TMPFILE1" | grep "Encryption key:off" > "$TMPFILE0"
                  OPENCOUNT=`wc -l < "$TMPFILE0"`
                  
                  # get the number of closed WIFIs
                  cat "$TMPFILE1" | grep "Encryption key:on" > "$TMPFILE0"
                  CLOSEDCOUNT=`wc -l < "$TMPFILE0"`
                  
                  #clear # clear screen
                  
                  echo "Found $OPENCOUNT open WIFI(s) and $CLOSEDCOUNT closed WIFI(s)."
                  
                  # get the total number of WIFIs (Cells)
                  cat "$TMPFILE1" | grep "Encryption key:" > "$TMPFILE0"
                  CELLCOUNT=`wc -l < "$TMPFILE0"`
                  
                  # Split the scan output into one file per cell; the files are , xx2, ...
                  #csplit --digits=1 -k "$TMPFILE1" '/Cell/' {*} 2> /dev/null > /dev/null
                  csplit --digits=1 -k "$TMPFILE1" '/ Cell [0-9][0-9]* - Address: [A-Fa-f0-9][A-Fa-f0-9]:[A-Fa-f0-9][A-Fa-f0-9]:[A-Fa-f0-9][A-Fa-f0-9]:[A-Fa-f0-9][A-Fa-f0-9]:[A-Fa-f0-9][A-Fa-f0-9]/' {*} 2>&1 >/dev/null
                  
                  # print the WIFI data
                  
                  if [ $CELLCOUNT -ge 0 ]
                  then
                    #echo "List of WIFI(s) with Channel, Encryption, Quality, Signal Level, MAC, ESSID:"
                    i=1 # number for the first WIFI MAC
                    #for loop_counter in $(seq 1 "$CELLCOUNT")
                    for ((loop_counter=1; loop_counter<=CELLCOUNT; loop_counter++))
                    do
                      # command line output
                      ACTCHANNEL="`cat xx$loop_counter | awk '/Channel:/{ print $1 }'`"
                      #echo -n "$ACTCHANNEL"
                      ACTENCRYPTION="`cat xx$loop_counter | awk '/Encryption/{ print $2 }' | cut -d":" -f2`"
                      #echo -n -e "\t$ACTENCRYPTION"
                      ACTQUALITY="`cat xx$loop_counter | awk '/Quality/{ print $1}'`"
                      #echo -n -e "\t$ACTQUALITY"
                      ACTSIGNALLEVEL="`cat xx$loop_counter | awk '/Quality/{ print $3}'`"
                      #echo -n -e "\t$ACTSIGNALLEVEL"
                      ACTMAC="`cat xx$loop_counter | awk '/Address/{ print $5 }'`"
                      #echo -n -e "\t$ACTMAC  "
                      #ACTESSID="`cat xx$loop_counter | grep ESSID | cut -d":" -f2`" # awk '/ESSID/{ print $1 }'`"
                      # get the ESSID with the quotation marks
                      ACTESSID=`cat xx$loop_counter | grep ESSID | cut -d ":" -f 2- | cut -c 1-129`
                      #echo $ACTESSID
                      # output for wifiscan. Start with the file name <mac>,<channel>,<plain_hexdump(ESSID)>.<mseconds>
                      ACTESSIDBASE=`echo -n $ACTESSID | xxd -p`
                      ACTTIMEMS=$(($(date +%s%N)/1000000))
                      ACTCHANNELNR="`echo "$ACTCHANNEL" | cut -d":" -f2`" # strip "Channel:"
                      ACTQUALITYS="`echo "$ACTQUALITY" | cut -d"=" -f2`" # strip "Channel: # strip "Quality="
                      ACTSIGNALLEVELS="`echo "$ACTSIGNALLEVEL" | cut -d"=" -f2`"  #strip "level="
                      ACTFILENAME="$WIFISCANDIR"/"$ACTMAC","$ACTCHANNELNR","$ACTESSIDBASE"."$ACTTIMEMS"
                      # store the data as CSV
                      echo -n "$ACTCHANNELNR " > "$ACTFILENAME"
                      echo -n "$ACTENCRYPTION " >> "$ACTFILENAME"
                      echo -n "$ACTQUALITYS " >> "$ACTFILENAME"
                      echo -n "$ACTSIGNALLEVELS " >> "$ACTFILENAME"
                      echo -n "$ACTMAC " >> "$ACTFILENAME"
                      echo -n "$ACTTIMEMS " >> "$ACTFILENAME"
                      echo -n "$ACTESSID" >> "$ACTFILENAME"
                    done
                  fi
                  # show the wireless status
                  cat /proc/net/wireless
                  
                  # cleanup: delete TMPFILE0 and temporary wifiscan files older than one minute
                  #/usr/bin/shred -f -x --iterations=1 --remove $TMPFILE0
                  rm -f $TMPFILE0
                  
                  find "$WIFISCANDIR" -mmin +1 -type f -exec rm {} \;
                  
                  # if only pingging to the AP has to be tested
                  if [[ ("$#" -gt 0) && ("$1" -eq 4) ]]
                  then
                    sleep 5 # wait 5 seconds
                  fi
                  
                done
              fi
            else  # offline; no ping/DNS lookup was successfull and we were not online before
              deadline_counter=$[$deadline_counter +1]
              echo "offline"
              connected=0
              rm -f /home/knoppix/Desktop/online
              online_loop_counter=0
            fi
          done # while deadline_counter
        fi # filtering with $1 > 1
        
        # the actual open WIFI failed the online test two times or we did not connect; loop to the next
        deadline_counter=0
        connected=0
        rm -f /home/knoppix/Desktop/online
        echo "Not connectet"
      done # for opencount; go to the next open WIFI (or make a new scan)
    fi # check of the first parameter
    
    # put the actual device offline before (maybe) switching to the mext
    ifconfig "$DEVICE" down
  done # for devicecount
  
done # while true,  end of the endless loop

exit 0
