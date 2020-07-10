#!/usr/bin/perl
########################################################################

=head1 NAME

s4p_pooldb.pl - create / update the disk pool database file

=head1 SYNOPSIS

s4p_pooldb.pl 
B<-d> I<database_file>
[B<-o> I<old_config_file>]
B<-n> I<new_config_file>
[B<-r>]
[B<-m>]

=head1 DESCRIPTION

Create or update the disk pool database file.
This file maintains several disk "pools", each with a certain number
of bytes left in the pool.  As space is allocated (see the ResPool
module), this number decreases; as it is deallocated, the number increases.

When called without the B<-o> option, it creates a new disk pool database
file using the configuration file specified with the (required) B<-n> option.

When called with the B<-o> option, it updates the disk pool database
file by adding the differences, on a pool by pool basis, between the new
and the old configuration file.  This allows updating on the fly, i.e.,
without resetting the disk pools or cleaning the data out.
Note that it is possible that a nearly full disk pool may be set to a
negative number if the new allocation is less than the old allocation.
However, this should not cause problems in the system.

Also, note that if the old file does not exist, it will be the same as
if run without the B<-o> option, EXCEPT that a B<-r> option will still
cause the "new" config file to be moved to the "old" config file name.

When called with both the B<-o> and the B<-r> option, the new allocation file
will be moved on top of the old one.  This allows an allocation station
to reconfigure itself by passing in the new allocation configuration
file as a work order.  In order to enable this, the %cfg_commands syntax
should be something like this:

    'UPDATE_POOLS' => '../s4p_pooldb.pl -r -o ../s4pm_allocate_disk.cfg -n'

The work order is appended onto this when called by stationmaster, 
and ends up replacing ../s4pm_allocate_disk.cfg after the disk 
pool update is complete.

The B<-m> indicates that the string is being run in multi-user mode. This
affects the final permissions on the new configuration file.

=head1 FILES

This is an example of an s4pm_allocdisk_pool.cfg configuration file contents.

$pool_size {"/vol1/data/output/MOD01/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD03/"} = 1000000000;

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# s4p_pooldb.pl,v 1.3 2008/01/10 20:43:34 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use DB_File;
use Getopt::Std;
use File::Copy;
use S4P;
use Safe;
use vars qw($opt_d $opt_n $opt_o $opt_r $opt_m);
BEGIN { require DB_File::Lock if ($^O =~ /Win32/); }

sub LOCK_SH { 1 }
sub LOCK_EX { 2 }
sub LOCK_NB { 4 }
sub LOCK_UN { 8 }

getopts('d:n:o:rm');

my $new_cfg_file = $opt_n;
my $old_cfg_file = $opt_o;
my $db_file = $opt_d;
if (!defined $new_cfg_file || !defined $db_file) {
  die "Usage: s4p_pooldb.pl [-u old_config_file] config_file database_file\n";
}

# Read config file
my $cpt = new Safe('CFG');
$cpt->rdo($new_cfg_file) or die "Cannot rdo $new_cfg_file: $!";

# If updating, we are going to add the difference of the old and new
if ($old_cfg_file && (-e $old_cfg_file)) {
    my $cpt = new Safe('OLD');
    $cpt->rdo($old_cfg_file) or die "Cannot rdo $old_cfg_file: $!";
    S4P::logger('INFO', "Found $old_cfg_file, updating with differences");
    foreach my $pool(keys %CFG::pool_size) {
        $CFG::pool_size{$pool} -= $OLD::pool_size{$pool};
    }
}
    
my ($db, %pool_size);
if ($^O =~ /Win32/) {
    $db = tie (%pool_size, "DB_File::Lock", $db_file, O_CREAT|O_RDWR, 0666, $DB_HASH, "write") 
        or die "Can't open $db_file: $!\n";
}
else {
    $db = tie (%pool_size, "DB_File", $db_file, O_CREAT|O_RDWR, 0666) 
        or die "Can't open $db_file: $!\n";
    my $fd = $db->fd;
    open (DB_FH, "+<&=$fd") or die "dup $!";

    # First do non-blocking lock, and warn that contention exists
    unless (flock (DB_FH, LOCK_EX | LOCK_NB)) {
        warn "$$: CONTENTION; must have exclusive lock! Waiting for write lock ($!) ....";
        # Now go into blocking lock and wait until we get our lock
        unless (flock (DB_FH, LOCK_EX)) {die "flock: $!"}
    }
}

# Remove non-existent pools (when modifying pre-existing database files)
foreach my $pool(keys %pool_size) {
    delete $pool_size{$pool} unless (exists $CFG::pool_size{$pool});
}

# Note that when updating number pool size may go negative
# This should be OK so long as the allocating routine understands not to
# allocate unless the number >= 0
foreach my $pool(keys %CFG::pool_size) {
    if ($old_cfg_file && (-e $old_cfg_file)) {
        $pool_size{$pool} += $CFG::pool_size{$pool};
    }
    else {
        $pool_size{$pool} = $CFG::pool_size{$pool};
    }
}
    
# Flush and unlock
$db->sync();

flock (DB_FH, LOCK_UN) if ($^O !~ /Win32/);
undef($db);
untie %pool_size;

# Replace the old config file if called for
# But leave the old work order so stationmaster can
# delete it.
if ($old_cfg_file && $opt_r) {
    chmod(0660, $old_cfg_file);
    copy($new_cfg_file, $old_cfg_file) or 
        die "Failed to move $new_cfg_file to $old_cfg_file: $!";
    S4P::logger('INFO', "Moved new config file $new_cfg_file to $old_cfg_file");
    chmod(0440, $old_cfg_file) unless ( $opt_m );
}
exit 0;
