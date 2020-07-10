#!/usr/bin/perl

=head1 NAME

stop_station - command line utility to stop a station

=head1 SYNOPSIS

stop_station.pl [$dir]

=head1 DESCRIPTION

This script is just a shell to call the actual S4P module
to stop a station.

=head1 SEE ALSO

L<tkstat(1)>

=head1 AUTHOR

Long Pham, NASA/GSFC, Code 610.2

=cut

################################################################################
# stop_station.pl,v 1.2 2006/09/12 19:43:50 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use S4P;
if ($ARGV[1]) {
    chdir $ARGV[1] or die "Cannot chdir to $ARGV[1]: $!";
}
# Call S4P module to actually do the restart
my $status = S4P::stop_station();
exit(! $status);
