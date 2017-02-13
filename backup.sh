#!/bin/bash

BACKUPDIR="/home/backup"
LASTMONTHDIR=lastmonth
TSNAME=timestamp.snar
BACKUPNAME=backup
DIRS="/home/sushi"

cd "$BACKUPDIR"

case "$1" in
	complete)
		tar -cvf "$BACKUPDIR"/complete.tar --exclude-from <(find "$BACKUPDIR" -size +30M) -g timestamp.snar "$DIRS"

	;;
	
	*)
		tar -czf "$BACKUPDIR"/complete.tgz -g ""
	;;
esac


#Abzug erstellen
#tar czf "$BACKUPDIR"/"$BACKUPNAME".$MYDATE.tgz -g "$BACKUPDIR/$TSNAME" "$DIRS" #2> /dev/null
