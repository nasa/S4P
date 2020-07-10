#!/usr/bin/perl

=head1 NAME

send_downstream - send output work orders downstream

=head1 SYNOPSIS

send_downstream.pl -l logfile

=head1 DESCRIPTION

Sends S4P work orders downstream.  
This is useful for failure handling, where you want to run the
station's script, perhaps with different arguments, and resume
the "chain" of activities.  As such, this would most often be
used in the context of %cfg_failure_handlers, e.g.:

  %cfg_failure_handlers = (
    'Fix' => 'subnot2request.pl DO.* && \
              send_downstream.pl -l NOTIF*.log && \
              remove_job.pl'
  );

Note that the logfile is (currently) mandatory.
Also, it is meant to be run WITHIN the job directory whose output
work orders are to be moved downstream.

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# send_downstream.pl,v 1.3 2008/05/19 20:19:51 lynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use vars qw($opt_l);
use Getopt::Std;
use S4P;
use Safe;

getopts('l:');

# Check usage and station config file
die("Usage: send_downstream -l logfile") unless ($opt_l);
die("Cannot find logfile $opt_l") unless (-f $opt_l);
die("Cannot find station configuration file ../station.cfg") 
    unless (-f '../station.cfg');
my $cpt = new Safe('CFG');
$cpt->rdo('../station.cfg') or
    die("Cannot process station configuration file ../station.cfg");

# Execute send_downstream:
my $priority;   # Currently not used
my $err = S4P::send_downstream($opt_l, \%CFG::cfg_downstream, $priority, 
    $CFG::cfg_root, $CFG::cfg_output_work_order_suffix);

exit(! $err);
