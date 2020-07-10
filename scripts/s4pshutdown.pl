#! /usr/bin/perl

=head1 NAME

s4pshutdown - shutdown script for S4P stations

=head1 SYNOPSIS

s4pshutdown.pl B<[-r]> B<[-g]>

=head1 DESCRIPTION

s4pshutdown is used to shutdown all S4P stations. It reads a file named
station.list, which simply has the list of station directories.
It goes through each directory, first removing all child's process and
next removing the stations from the system .

=head1 ARGUMENTS

=over 4

=item B<-r>

Recursive:  shuts down children as well as parent stationmaster.

=item B<-g>

Gently:  uses gentle shutdown of stations.  
(Stopping of jobs is dependent on whether it is in multi-user mode.)

=back

=head1 FILES

=over 4

=item station.list 

A simple list of the station directories to be started.
It is assumed to be in the current directory.

=back

=head1 AUTHOR

Long Pham, NASA/GSFC, Code 610.2

=cut

################################################################################
# s4pshutdown.pl,v 1.4 2007/07/10 17:09:27 lynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use S4P;
use strict;
use Cwd;
use Getopt::Std;

use vars qw($opt_g $opt_r);

getopts('gr');

# Default to station list if no file exists
my $listfile = ($ARGV[0] eq "") ? "station.list" : $ARGV[0];

# Check to see if file exist
if ( ! -f $listfile ) {
    die "Cannot find station list $listfile!\n";
}
# Open station list file for reading
open (FD, $listfile);
my $dirname;
my $job;
my $gently = $opt_g ? 'gently' : undef;

my $start_dir = cwd() or die "Cannot determine starting directory";

foreach $dirname(<FD>){
    chomp $dirname;
    # Change to directory
    chdir ($dirname);
    # If option is set for terminating child's process
    if ($opt_r) {
       # Get current directory path
       my $cur_dir = cwd();
       # Open directory
       opendir (JOB_FD, $cur_dir);
       # Read directory
       my @JOB_DIR = readdir(JOB_FD);
       # Loop through each running job (if any)
       foreach $job(@JOB_DIR) {
           chomp $job;
           # If there are running jobs
           if ($job =~ /^RUNNING/) {
               chdir ("$job");
               # Remove child process
               S4P::end_job(cwd());
               chdir ("..");
           }
       }
       # Close job directory
       close (JOB_FD);
    }
    # Call stop station to remove parent process
    S4P::stop_station($gently);
    # Go back to original directory
    chdir ($start_dir);
}
# Close file
close(FD);
