#!/usr/bin/perl -w

=head1 NAME

station_control.pl - Starts/Stops and monitors the stationmasters in a S4P string

=head1 SYNOPSIS

station_control.pl B<-f> station_control.cfg

=head1 DESCRIPTION

station_control.pl is a daemon process that monitors the activity in the 
S4P processing string. If there isn't any activity, the stationmasters 
in all the stations defined in station.list are shutdown. Activity is defined 
as the presence of a "DO" work order, a "RUNNING" directory or a "FAILED" 
directory.  If stationmasters are not running and there is a pending work 
order, station_control.pl will start all the stations in the processing 
string.

station_control.pl writes a pid file in the station directory when it
is active. This file contains the process id for the daemon. The pid
file is removed when the daemon exits.  station_control.pl also writes 
a log file to the station directory.

=head1 CONFIGURATION FILE

$cfg_daemon_sleep_time =  180; 

$station_dir = "$ENV{'DAACDIR'}/stations/ingest";

@cfg_head_stations = ("pickup");

=head1 STATION CONTROL SHELL SCRIPT

The following is an example of a shell script can be used to start and 
stop the station_master.pl daemon. Modify it to fit your environment.

#! /bin/sh

killall=/sbin/killall
mc=/usr/daac/dev/bin/station_control.pl
echo=echo

case "$1" in
  'start')
     # station_control startup
     $echo -n "station_control daemon:"

     $echo -n " mc"
     $mc -f /usr/daac/dev/etc/S4PIngest/station_control.cfg

     $echo "."
     ;;

  'stop')
     $killall -v -15 station_control.pl
     ;;

  *) echo "usage: $0 {start|stop}"
     ;;
esac

exit 0


=head1 AUTHOR

Bob Mack, NASA/GSFC, Code 610.2

=cut

################################################################################
# station_control.pl,v 1.2 2006/09/12 19:43:50 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use POSIX;
use IO::File;
use Fcntl ':flock';
use S4P;
use Cwd;
use Getopt::Std;
use vars qw ($opt_f);

my $listfile = 'station.list';
my ($daemon_sleep_time, $cfg_daemon_sleep_time);
my $station_dir;
my @cfg_head_stations;

getopts('f:');

##++
## Read in the configuration file.
##
if (! $opt_f) {
  die "Usage: station_control.pl -f station_control.cfg\n";
}

if (-e $opt_f) {
  my $cstring = S4P::read_file($opt_f);
  exit 1 if ! $cstring;
  eval ($cstring);
  die "eval: $@\n", if $@;
}
else {
  die "$opt_f not found. Exiting.\n";
}

##++
## Set the sleep time or default to 180 seconds.
##--
$daemon_sleep_time = $cfg_daemon_sleep_time || 180;

##++
## Setup how to handle signals
##--
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signal_handler;
$SIG{CHLD} = sub { while ( waitpid(-1, WNOHANG)>0 ) {} };

##++ 
## Change to the S4P station root directory.
##--
chdir ($station_dir)
        || die "Could not change to $station_dir: ($!)";

##++
## Set up the PID file. Used to determine if the daemon is running.
##--
my $pid_file = ('station_control.pid');
my $fh = open_pid_file($pid_file);

##++
## Open the log file
##--
my $cm_log = ('station_control.log');
my $lfh = open_log_file($cm_log);

##++
## Let's create a daemon.
##--
my $pid = fork;
exit if $pid;
perish ("ERROR: Couldn't fork: $!\n") unless defined($pid);

POSIX::setsid()
     or perish ("ERROR: Can't start a new session:$!\n");

##++
## Get the process id and save it to the PID file.
##--
my $cpid = $$;
print $fh $cpid;
close $fh;

##++
## Close these file handles to avoid the child from re-acquiring
## the /dev/tty device. Could confuse subprocesses if they are
## looking for the standard file handles to be open.
##--
close $_ foreach (\*STDIN, \*STDOUT, \*STDERR);

##++
## Read station.list file and set up the head station.
##-- 
if (! -e $listfile) {
  unlink $pid_file;  # Remove the pid file.
  perish ("ERROR: Cannot find station list file: $listfile\n");
}
open (FD, $listfile);
my @stations = <FD>; 
close (FD);

##++
## Check for the head stations.
##--
foreach (@cfg_head_stations) {
  if (! -e $_) {
    unlink $pid_file;  # Remove the pid file.
    perish ("ERROR: Cannot find station: $_\n");
  }
}

##++
## Loop until the signal to stop comes.  
##--
logger ("INFO: Station control starting...\n");
my $activity;
my $waiting_job;
my $time_to_die = 0;
until ($time_to_die) {

##++
## Check to see if the string is already ON by checking one of the head 
## stations.
##--
  $activity = 0;
  $waiting_job = 0;
  if (S4P::check_station($cfg_head_stations[0])) {

##++
## If the string is running, then monitor the processing string activity.
##--
    foreach (@stations) {
      chomp $_;
      chdir ($_) || perish ("ERROR: Could not change to $_: ($!)");
      if( defined (<RUNNING.*>) ){
        $activity++;
      }
      if( defined (<FAILED.*>) ){
        $activity++;
      }
      if( defined (<DO.*>) ){
        $activity++;
      }
      chdir ("..") || perish ("ERROR: Could not change back to parent:($!)");
    } # End foreach loop

##++
## If there isn't any activity, then stop the stationmasters. 
##--
    if (!$activity) {

      my $rc = S4P::exec_system ("s4pshutdown.pl");  
      if (!$rc) { # Success
        logger ("INFO: Stationmasters stopped for $station_dir.\n");
      }
      else { # Failure
        perish ("ERROR: Failure to stop stationmasters. Return code = $rc \n");
      }
    } # End if activity

  } # End if stationmaster running

##++
## If the stations are not running, then check for pending work orders
## in the head station.
##--
  else {
    foreach (@cfg_head_stations) {
      chdir ($_) || perish ("ERROR: Could not change to $_: ($!)");
      if( defined (<DO.*>) ){
         logger ("INFO: Pending work order in $_\n");
         $waiting_job++;
      }
      chdir ("..") || perish ("ERROR: Could not change back to parent:($!)");
    }

##++
## If there are pending work orders, then start the stationmasters.
##--
    if ($waiting_job) {

      my $rc = S4P::exec_system ("s4pstart.ksh");  
      if (!$rc) { # Success
        logger ("INFO: Stationmasters started for $station_dir\n");
      }
      else { # Failure
        perish ("ERROR: Failure to start stationmasters. Return code = $rc \n");
      }

    } # End if job is waiting

  } # End else not running

  sleep ($daemon_sleep_time);

} # End loop until time to die

unlink $pid_file;  # Remove the pid file.
logger ("INFO: Station control stopped.\n");
close $lfh;

exit 0;

##++
## What to do when the signal is received.
##--
sub signal_handler {
   $time_to_die = 1;
}

#################################################################
#
# Accessories
#
#################################################################

##++
## Set up PID file to flag whether daemon is running or not.
##--

sub open_pid_file {

  my $file = shift;
  if (-e $file) {  # pid file already exists
    my $fh = IO::File->new($file) || return;
    my $pid = <$fh>;
    die "Cleaner process already running with PID $pid" if kill 0 => $pid;
    warn "Removing PID file for defunct cleaner process $pid.\n";
    die "Can't unlink PID file $file" unless -w $file && unlink $file;
  }
  return IO::File->new($file, O_WRONLY|O_CREAT|O_EXCL, 0644)
    or die "Can't create $file: $!\n";

}

##++
## Setup the log file and error reporting routines.
##--
sub open_log_file {
  my $log_file = shift;
  my $lfh = IO::File->new($log_file, O_WRONLY|O_APPEND|O_CREAT, 0644) ||
     die "Cannot open $log_file ($!)";
  $lfh->autoflush(1);
  return $lfh;
}

sub logger {
  my $message = shift;
  my $msg = (&timestamp . " $message");
  flock ($lfh, LOCK_EX);
  print $lfh $msg;
  flock ($lfh, LOCK_UN);
}

sub perish {
  my $message = shift;
  logger ($message);
  close $lfh;
  exit 1;
}

sub timestamp {
    return format_time(localtime);
}

sub format_time {
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $_[5]+1900, $_[4]+1,
                          $_[3], $_[2], $_[1], $_[0]);
}
