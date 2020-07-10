#!/usr/bin/perl

=head1 NAME

dbls - list contents of a DB_File database

=head1 SYNOPSIS

dbls.pl database

=head1 DESCRIPTION

dbls lists the contents of a DB_File database as:
"key => value".

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# dbls.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use DB_File;

my %hash;

die "Usage: dbls.pl database" if (! $ARGV[0]);

# Open up database
my $db = tie (%hash, "DB_File", $ARGV[0], O_RDONLY) or die ("Cannot open $ARGV[0]: $!");
my $key;
foreach $key (sort keys %hash) {
    printf ("%s\t=>\t%s\n", $key, $hash{$key});
}
exit(0);
