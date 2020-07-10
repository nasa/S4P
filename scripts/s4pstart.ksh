# !/bin/ksh
# =head1 NAME
#
# s4pstart - startup script for S4P stations
#
# =head1 SYNOPSIS
#
# s4pstart.ksh
# [-u umask]
# [I<stationlist_file>]
#
# =head1 DESCRIPTION
#
# s4pstart is used to start up a whole S4P "string". It reads a file named
# station.list, which simply has the list of station directories.
# It then goes through each one, starting it up with nohup in background.
# By default, s4pstart looks for a file named in the argument passed to it
# as the station list file. Otherwise, it defaults to station.list in the
# current directory.
#
# =head1 FILES
#
# =over 4
#
# =item Station List File
#
# A simple list of the station directories to be started. If not explictily
# specified as an argument, it is assumed to be named station.list in the 
# current directory.
#
# =item -u umask
#
# This option passes the umask setting onto stationmaster.pl which will use
# the value when creating and moving files (e.g. work orders)
#
# =back
#
# =head1 AUTHOR
#
# Chris Lynnes, NASA/GSFC, Code 610.2
#
# =cut
################################################################################
# s4pstart.ksh,v 1.4 2008/08/22 15:24:10 clynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

# Read in possible -u option that sets the umask
while getopts "u:" arg
do
    case $arg in
        u)
            use_umask=$OPTARG
    esac
done
shift $((OPTIND - 1))

# Set listfile equal to first argument passed in or default to station.list
listfile=${1:-station.list}
if [ ! -f $listfile ]; then
    echo Cannot find station list $listfile!
    exit 1
fi

if [ -f nohup.out ]; then
    echo '--------------------------------------------------' >> nohup.out
    date >> nohup.out
fi
for i in `cat $listfile`; do
    echo Starting up $i...
    if [ $use_umask ]; then
        nohup stationmaster.pl -d $i -u $use_umask &
    else
        nohup stationmaster.pl -d $i &
    fi
done
