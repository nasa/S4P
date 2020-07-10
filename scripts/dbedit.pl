#!/usr/bin/perl

=head1 NAME

dbedit - edit DB_File database

=head1 SYNOPSIS

dbedit.pl -d database -k key -v value

=head1 DESCRIPTION

dbedit edits a DB_File database in place, obeying file locks where applicable.
Use this tool only for good and never for evil.

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# dbedit.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use Getopt::Std;
use DB_File;
use vars qw($opt_d $opt_k $opt_v);

sub LOCK_SH {1}
sub LOCK_EX {2}
sub LOCK_NB {4}
sub LOCK_UN {8}

getopts('d:k:v:');

# Check for all arguments
die("Usage: dbedit -d db -k key -v value\n") if (!$opt_d || !$opt_k || !$opt_v);

my %hash;

# Open up database
my $db = tie (%hash, "DB_File", $opt_d, O_RDWR, 0666) or die ("Cannot open $opt_d: $!");
die ("$opt_k not in database\n") unless (exists $hash{$opt_k});
my $fd = $db->fd;  # For locking
open(DB_FH, "+<&=$fd") or die ("Cannot open file device for lock");
unless (flock (DB_FH, LOCK_EX | LOCK_NB)) {
  warn ("Waiting for write lock ($!)...");
  die("flock error: $!") unless (flock (DB_FH, LOCK_EX));
}
$hash{$opt_k} = $opt_v;
$db->sync;                # Flush write
flock (DB_FH, LOCK_UN);   # Unlock
undef $db;
untie %hash;
close (DB_FH);
print STDERR "$opt_k changed to $opt_v\n";
exit(0);

