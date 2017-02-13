#!/bin/bash
#
# mtutest.sh: Simple current minimal maximum MTU estimation, with the IP as script argument.

# no unset variables
set -u

MinPingSize=57 # net size (without 28 bytes of overhead)
PKT_SIZE=$MinPingSize # ping start size
MaxPingSize=3000
PingHost=$1 # other side, e. g. AP

# ping with 56 bytes default size
ping -W 1 -c 1 $PingHost >/dev/null 2>&1
retval=$?
if [ $retval -ne 0 ] ; then
  echo "Can't ping $PingHost at all."
  exit
else
  echo "$PingHost seems to be alive; proceeding."
fi
  
# ping till ping fails
while [ $retval -eq 0 ] ; do
  ping -W 1 -M do -c 1 -s $PKT_SIZE $PingHost >/dev/null 2>&1
  retval=$?
  if [ $PKT_SIZE -ge 3000 ] ; then
     break;
  fi
  if [ $retval -eq 0 ] ; then # increase ping size only if successfull
    PKT_SIZE=$((PKT_SIZE+1))
  fi
  echo -n .
done
   
echo 

# Now we are at the first failed ping; decrease to the last successfull ping size.
if [ $retval -ne 0 ] ; then
  PKT_SIZE=$((PKT_SIZE-1))
fi
    
printf "The current minimal maximum MTU is $((PKT_SIZE + 28)) \n"
    
exit 0
