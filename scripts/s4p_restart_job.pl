#!/usr/bin/perl

=head1 NAME

s4p_restart_job - restart a failed job 

=head1 SYNOPSIS

s4p_restart_job.pl
[B<-f>]
[B<-s> I<suffix>]

=head1 DESCRIPTION

This script restarts a failed job.

It first tries a regular restart, using S4P::restart_job().
This will fail if the job.status file is missing or indicates that
the job is still running.

If the B<-f> (force) option is specified, it will try a more brute
force approach.  Note that in the case of the job.status file being
missing, the B<-s> I<suffix> should be specified so it has an idea what to name it back to.
Note that this may not work on stations with unusual input_work_order_patterns.

=head1 NOTE

This subsumes the functionality of restart_job.pl, which is now deprecated.

=head1 AUTHOR

Long Pham and Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# s4p_restart_job.pl,v 1.2 2006/09/12 19:43:50 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use Getopt::Std;
use S4P;
use Cwd;
use File::Copy;
use vars qw($opt_f $opt_s);

getopts('fs:');

# Call S4P module to actually do the restart
my $restart_status = S4P::restart_job();
exit 0 if $restart_status;
exit 1 unless $opt_f;

warn("Failed to restart_job in normal mode, going to force...\n");
my ($status, $pid, $owner, $orig_wo, $comment) = S4P::check_job('.');
die ("Must specify new work order suffix on command line\n") unless ($orig_wo || $opt_s);

# Look for work order to move up.
my @wo = glob('DO.*');

# Check to see that we got one and only one
die "No work orders found to restart\n" unless (@wo);
die "Too many work orders, don't know which one to restart\n" if (scalar(@wo) > 1);

# Set new work order name if we didn't get it from job.status
$orig_wo ||= $wo[0] . ".$opt_s";

# Find corresponding log file
my $work_order = $wo[0];
my $log_pattern = "$work_order.log";
$log_pattern =~ s/^DO\.//;
my @logs = glob($log_pattern);
my $log_file = $logs[0];

# Now move the files
move ($work_order, "../$orig_wo") or die "Cannot move work order file $work_order to $orig_wo: $!\n";
move ($log_file, '..') or die "Cannot move log file $log_file to parent directory: $!\n";
print STDERR "Job restarted.\n";
exit(0);
