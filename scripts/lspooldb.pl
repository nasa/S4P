#!/usr/bin/perl
########################################################################

=head1 NAME

lspooldb - list contents of disk pool db file

=head1 SYNOPSIS

lspooldb.pl  
[B<-s[ummary]>
allocdisk.db

=head1 DESCRIPTION

List the contents of the disk pool DB file. This includes the disk pool name
and the current size of the pool (space remaining). 

With the -s[ummary] flag, the only output is the sum of all disk pool usages, 
that is, the total space available by all pools (in GB).

=head1 AUTHOR

Bob Mack, NASA/GSFC, Code 610.2

=cut

################################################################################
# lspooldb.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use Getopt::Long;
use DB_File;

my $summary = undef;

GetOptions( "summary"   => \$summary,
);

sub LOCK_SH { 1 }
sub LOCK_EX { 2 }
sub LOCK_NB { 4 }
sub LOCK_UN { 8 }

my %pool_size;
my $psz = $ARGV[0];
my ($db, $fd);

if (!defined $psz) {
  print "Usage: lspool.pl allocdisk.db\n";
  exit 0;
}

$db = tie (%pool_size, "DB_File", $psz, O_CREAT|O_RDWR, 0666)
   or die "Can't open $psz:$!\n";
$fd = $db->fd;
open (DB_FH, "+<&=$fd")
  or die "dup $!";

unless (flock (DB_FH, LOCK_SH | LOCK_NB)) {
  print "$$: CONTENTION; can't read during write update!
              Wating for read lock ($!) ....";
  unless (flock (DB_FH, LOCK_SH)) {die "flock: $!"}
}

my $sum = 0;
foreach my $key (keys (%pool_size)) {
   my $ps = commify($pool_size{$key});
   $sum += $pool_size{$key};
   print "$key $ps\n" unless ( $summary );
}
print $sum/(1024*1024*1024) . "\n" if ( $summary );

flock (DB_FH, LOCK_UN);
undef $db;
untie %pool_size;
close (DB_FH);

exit 0;

sub commify {

### Taken from Perl Cookbook, O'Reilly

    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

