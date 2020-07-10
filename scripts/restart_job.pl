#!/usr/bin/perl

=head1 NAME

restart_job - restart a failed job 

=head1 SYNOPSIS

restart_job.pl

=head1 DESCRIPTION

This script is just a shell to call the actual S4P module
to restart a failed job.

Monitor(3), tkstations(1)

=head1 AUTHOR

Long Pham, NASA/GSFC, Code 610.2

=cut

################################################################################
# restart_job.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use S4P;
use Cwd;

# Call S4P module to actually do the restart
my $restart_status = S4P::restart_job();
exit(! $restart_status);
