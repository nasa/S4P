#!/usr/bin/perl

=head1 NAME

remove_job - remove all jobs from failed directory

=head1 SYNOPSIS

remove_job.pl

=head1 DESCRIPTION

This script is just a shell to call the actual S4P module
to remove a failed job.

Monitor(3), tkstations(1)

=head1 AUTHOR

Long Pham, NASA/GSFC, Code 610.2

=cut

################################################################################
# remove_job.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use S4P;
use Cwd;

# Call S4P module to actually do the job removal
my $remove_status = S4P::remove_job();
exit(! $remove_status);
