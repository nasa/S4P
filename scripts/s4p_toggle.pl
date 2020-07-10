#! /usr/bin/perl

=head1 NAME

s4p_toggle - Suspends all jobs in S4PA

=head1 SYNOPSIS

s4p_toggle.pl [B<-d> I<station_dir>] [B<-s | -r>]

=head1 DESCRIPTION

s4p_toggle is used to suspend and resume jobs in bulk. It reads a file named
station.list, which simply has the list of station directories.
It goes through each directory, suspending or resuming all jobs depending on
the command line argument.

=head1 ARGUMENTS

=over 4

=item B<-d> I<station_dir>

Suspend/resume jobs in specified station.

=item B<-r>

Resume jobs.

=item B<-s>

Suspend jobs.

=back

=head1 FILES

=over 4

=item station.list 

A simple list of the station directories to be started.
It is assumed to be in the current directory.

=back

=head1 AUTHOR

Christopher Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# s4p_toggle.pl,v 1.1 2007/07/06 19:38:54 lynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use S4P;
use strict;
use Cwd;
use Getopt::Std;

use vars qw($opt_d $opt_r $opt_s);

getopts('d:rs');

die "You must specify either -r (resume) or -s (suspend)\n"
    unless ($opt_r ^ $opt_s);

my @stations = ($opt_d) if $opt_d;


# Read stations from station list if not specified on command line
unless ($opt_d) {
    my $start_dir = cwd() or die "Cannot determine starting directory";
    # Default to station list if no file exists
    my $listfile = ($ARGV[0] eq "") ? "station.list" : $ARGV[0];
    
    # Check to see if file exists
    if ( ! -f $listfile ) {
        die "Cannot find station list $listfile!\n";
    }
    # Open station list file for reading
    open (FD, $listfile);
    my $dirname;
    foreach $dirname(<FD>){
        chomp $dirname;
        push @stations, "$start_dir/$dirname";
    }
}
close(FD);

my $job;

my $dir;
foreach $dir(@stations) {
    # Change to directory
    chdir ($dir);
    # If option is set for terminating child's process
    # Get current directory path
    # Open directory
    opendir (JOB_FD, '.');
    # Read directory
    my @JOB_DIR = grep {-d $_ && $_ =~ /^RUNNING/} readdir(JOB_FD);
    close (JOB_FD);
    exit(0) unless @JOB_DIR;

    # Loop through each running job (if any)
    foreach $job(@JOB_DIR) {
       chomp $job;
       # If there are running jobs
       if ($opt_s) {
           if (!(-r "$job/SUSPEND")) {
               # Remove child process
               S4P::suspend_job_child($job);
           }
       }
       elsif ($opt_r) {
           if (-r "$job/SUSPEND") {
               # Remove child process
               S4P::resume_job_child($job);
           }
       }
    }
    # Close job directory
}
