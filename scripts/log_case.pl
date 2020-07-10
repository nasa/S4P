#!/usr/bin/perl

=head1 NAME

log_case - submit an entry to the case-based reasoning log file

=head1 SYNOPSIS

log_case.pl
B<type>
B<exit_code>
B<info>

=head1 DESCRIPTION

B<log_case.pl> is a simple wrapper for the S4P::log_case() function
that supports adding an entry to the case-based reasoning log file via
a command line script.

The arguments in order must be:

=over 4

=item type

A letter representing the case type:

  F = Fault
  R = Recovery action
  D = Diagnosis
  M = Manual override or action

=item exit_code

The exit code that is to be passed into the case-based reasoning log file.

=item info

A string containing some information about the case.

=back

=head1 AUTHOR

Stephen W Berrick, NASA/GSFC, Code 610.2

=cut

################################################################################
# log_case.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use S4P;

my $type      = $ARGV[0];
my $exit_code = $ARGV[1];
my $info      = $ARGV[2];

if ( $ENV{'CBR_LOG_FILE'} ) {

    my $logfile = $ENV{'CBR_LOG_FILE'};

    if ( $logfile and $logfile ne "" ) {
        S4P::log_case($logfile, $type, $exit_code, $info);
    }
}
