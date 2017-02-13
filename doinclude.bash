:
##########################################################################
# Shellscript:	doinclude - process "#include" directives
# Author     :	Heiner Steven <heiner.steven@odn.de>
# Date       :	07.07.1999
# $Id: doinclude,v 1.5 2005/06/01 20:01:32 heiner Exp $
##########################################################################
# Description
#   Reads the input, and replaces each line of the form
#	#include "filename"
#   with the contents of the specified file.
#
# Notes
#    o	Included files may in turn include other files
#    o	The limit of directly or indirectly included files is 100
#    o	The input is completely read and stored into a file
#    o	The input data is processed once for each "#include"
##########################################################################

PN=`basename "$0"`			# Program name
VER=`echo '$Revision: 1.5 $' | cut -d' ' -f2`

MaxIncludes=100				# Max. "#include" file nesting

Usage () {
    echo >&2 "$PN - process \"#include\" directives, $VER (stv '99)
usage: $PN [-v] [inputfile ...]
   -v: print names of included files"
    exit 1
}

Msg () {
    for MsgLine
    do echo "$PN: $MsgLine" >&2
    done
}

Fatal () { Msg "$@"; exit 1; }

set -- `getopt hv "$@"` || Usage
[ $# -lt 1 ] && Usage			# "getopt" detected an error

Verbose=no
while [ $# -gt 0 ]
do
    case "$1" in
	-v)	Verbose=yes;;
	--)	shift; break;;
	-h)	Usage;;
	-*)	Usage;;
	*)	break;;			# First file name
    esac
    shift
done

Work=${TMPDIR:=/tmp}/if$$.work		# Working copy of input data
Tmp=${TMPDIR:=/tmp}/if$$.tmp		# Temporary file

# Remove files at end of script or after receipt of signal
trap 'rm -f "$Work" "$Tmp" >/dev/null 2>&1' 0
trap "exit 2" 1 2 3 13 15

cat "$@" > "$Work" && chmod u+w "$Work"	# Work on a copy of the input data
[ -s "$Work" ] || exit 0		# No data - nothing to do!

includecnt=0
while :
do
    # Does the input contain "#include" directives?
    incline=`egrep '^[ 	]*#include[ 	]*"[^"]*"[ 	]*$' "$Work" | head -1`
    [ -n "$incline" ] || break		# No further include directives

    incfile=`expr "$incline" : '[ 	]*#include[ 	]"\([^"]*\)"[ 	]*'`
    [ -n "$incfile" ] || Fatal "ERROR: invalid #include directive: \"$incline\""
    [ -r "$incfile" ] || Fatal "ERROR: cannot include file: $incfile"
    [ $Verbose = yes ] && Msg "including file \"$incfile\""

    # The reason for the upper limit on the number of file inclusions
    # is to termate the script if files include each other,
    # i.e. file "a": #include "b", file "b": #include "a"
    [ $includecnt -ge $MaxIncludes ] &&
    	Fatal "ERROR: #include nesting deeper than $MaxIncludes"

    # "sed" does not handle "/" characters within the file name, so
    # quote them.
    # A note on the quoting:
    #	"sed" will change '\\\\' to '\\'.  Later on the
    #	shell will replace '\\' with '\', which is what we want.
    filepattern=`echo "$incfile" | sed 's:/:\\\\/:g'`

    # Now use "sed" to replace the whole "#include" line with the
    # contents of the file
    sed '/^[ 	]*\#include[ 	]*"'"$filepattern"'"[ 	]*$/{r '"$incfile"'
d;}' "$Work" > "$Tmp" && mv "$Tmp" "$Work" || exit 1
    includecnt=`expr $includecnt + 1`
done

# Print the result. The temporary files will be cleaned up automatically.
cat "$Work"
