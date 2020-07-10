#! /usr/bin/perl
#
#Script to check running jobs to see if they are still really running, and if not tell them to look at the flowers
#
use strict ;
use S4P ;
use Cwd ;
use Getopt::Std ;
use Safe ;

use vars qw($opt_c) ;

getopts('c:') ;

my $compartment = new Safe 'CFG' ;
$compartment->share('@station_list_files','$killflag', '$sleeptime', '$lockfile', '$notify', '$station_root') ;
$compartment->rdo($opt_c) or
    S4P::perish(1, "main: Cannot read config file $opt_c in safe mode: $!") ;

dump_config() ;

# Check lockfile to see if we're already running

# Start work/sleep loop here
while (1) {

# Construct list of stations to check for zombied processes
   my @stations = load_stations() ;

   handle_zombies(\@stations) ;
   sleep($CFG::sleeptime) ;
}

sub handle_zombies {
   my $stations_r = shift ;

   my @stations = @{$stations_r} ;

# Create a linked list of parent/child processes with current run state for each pid
   my %psmap = load_ps_info() ;

   my $odir = cwd() ;
   my $mailfile = "|mailx -s \"Zombies detected\" $CFG::notify" ;
   my $zmesg = undef ;

# Look at each job and determine if the child pid is a zombie.
   foreach my $stn (@stations) {
      foreach my $job (glob("$stn/RUNNING*")) {
         my ($status, $pid, $owner, $orig_wo, $comment) = S4P::check_job($job) ;
         if (check_for_zombie($pid,\%psmap)) {
            $zmesg .= "$job is a zombie!\n" ;
            print "$job is a zombie!\n" ;
            if ($CFG::killflag) {
               chdir($job) ;
               if (S4P::alert_job($job, 'END')) {
                  S4P::logger('INFO', "Job terminated") ;
                  $zmesg .= "Job terminated\n" ;
               } else {
                  S4P::logger('ERROR', 'Failed to terminate job') ;
                  $zmesg .= "Failed to terminate job\n" ;
               } 
               chdir($odir) ;
            }
         }
      }
   }

   if (($zmesg) && ($CFG::notify)) {
      open(MAIL,$mailfile) or die "error opening pipe to mailx\n" ;
      print MAIL $zmesg ;
      close(MAIL) ;
   }

   return() ;
}

sub check_for_zombie {
# find child of specified process and check it's state
   my $pid = shift ;
   my $psmap_r = shift ;
   my %psmap = %{$psmap_r} ;

   my $zstat ;

# if no child then all is OK
   return(undef) unless ($psmap{'children'}{$pid}) ;

   foreach my $cpid (@{$psmap{'children'}{$pid}}) {
      $zstat ||= check_for_zombie($cpid,$psmap_r) ;
      $zstat = 1 if ($psmap{'status'}{$cpid} eq "Z") ;
   }
   return($zstat) ;
}

sub load_ps_info {

   my %psmap ;

   my @res = readpipe("ps -A -o pid,ppid,s") ;
   chomp(@res) ;
   shift @res ;
   while (my $pinfo = shift @res) {
      $pinfo =~ s/\s/,/g ;
      $pinfo =~ s/,+/,/g ;
      $pinfo =~ s/^,// ;
      my ($pid,$ppid,$stat) = split /,/,$pinfo ;
      push @{$psmap{'children'}{$ppid}},$pid ;
      $psmap{'status'}{$pid} = $stat ;
   }
   return(%psmap) ;
}

sub load_stations {
   my @stations ;

   my @station_list_files = @CFG::station_list_files ;

   if ($CFG::station_root) { @station_list_files = glob("$CFG::station_root/*/station.list") ; }

   foreach my $f (@station_list_files) {
      open(IN,$f) or die "Error opening $f for read\n" ;
      my @stns = <IN> ;
      close(IN) ;
      chomp(@stns) ;
# s4pm station.list files do not have full paths, so must provide
      if ($f =~ /s4pm/) {
         my @p = split /\//,$f ;
         pop @p ;
         my $path = join "/",@p ;
         foreach my $stn (@stns) { push @stations,$path."/".$stn ; }
      } else {
         push @stations,@stns ;
      }
   }
   return(@stations) ;
}

sub dump_config {
   my $msg = "Starting $0 on ".`hostname`." with this configuration:\n" ;
   $msg .= "station.list files:\n" ;
   foreach my $stn (@CFG::station_list_files) {
      $msg .= "\t".$stn."\n" ;
   }
   $msg .= "killflag: $CFG::killflag\n" ;
   $msg .= "sleeptime: $CFG::sleeptime\n" ;
   $msg .= "notify: $CFG::notify\n" ;

   print $msg ;

   return() ;
}
