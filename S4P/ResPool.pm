#!/usr/bin/perl -w
#######################################################################

=head1 NAME

ResPool - general utilities to manipulate DB_FILE resource pool database

=head1 SYNOPSIS

=for roff
.nf

  use S4P::ResPool;

  $size = S4P::ResPool::read_from_pool($pool);

  $size = S4P::ResPool::update_pool($pool, $size, $psz);

  S4P::ResPool::write_to_pool($pool, $size, $psz);

  $pcontents = S4P::ResPool::ls_pool($psz);

  S4P::ResPool::create_pools($pool_cfg_file, $output_db_file);

=head1 DESCRIPTION

ResPool utilities manipulate a DBM database (following the pattern from
the Perl Cookbook by Torkington and Christiansen). It allows you to use the 
same standard operations on hashes bound to DBM files as you do on
hashes in memory.  In the following example, the ResPool DBM database 
associates a disk pool location and the amount of disk space allocated 
to the disk pool.  The ResPool DBM file (hash) may be initially defined 
as follows:

$pool_size {"/var/scratch/trmm_data_mining/in/"} = 4400000000;
$pool_size {"/var/scratch/trmm_data_mining/out/"} = 100000000;
$pool_size {"/var/scratch/trmm_data_mining/out2/"} = 100000000;

The size will be updated as needed during data processing using the 
ResPool routines (see examples).

=head2 read_from_pool

read_from_pool reads a value from the pool DB_file using pool and 
database pathname as input. The size returned is the amount of 
pool space available.

=head2  update_pool

update_pool updates the pool DB_file using the value, pool
and database pathname as input. In order to decrease the pool
amount, value must be negative.  Positive values will increase
the pool amount. The size returned is the amount of bytes 
requested if the update is successful.  Otherwise the value is 0.

=head2  write_to_pool

write_to_pool writes a value to the pool DB_file using the value, pool
and database pathname as input.

=head2 ls_pool

ls_pool lists the contents of the pool DB_file.

=head2 create_pools

Creates the DB_File output file given an input pool configuration file.

=head1 CONFIGURATION FILE

Disk pools are defined for a paricular data type.  Each data type
is given a pool location. Each data type file has a known maximum
size.  The pool definitions are set up in a configuration file. These
values don't change during data processing. (They may be modified by 
an operator as pool requirements change.) 

The following is an example of the contents of configuration file. The 
first hash (datatype_maxsize) relates the product file maximum size 
(value) to the data type (key). The second hash (datatype_pool) relates 
a pool or directory location (value) with the data type (key).

%datatype_maxsize = (
                     '2A25' => 254000000,
                     'GAGE' => 4500000,
                     'JOHN' => 4500000
                     );

%datatype_pool = (
                  '2A25' => "/var/scratch/trmm_data_mining/in/",
                  'GAGE' => "/var/scratch/trmm_data_mining/out/",
                  'JOHN' => "/var/scratch/trmm_data_mining/out2/" 
                  );

=head1 EXAMPLE 1

=for roff

use strict;
use S4P;
use S4P::ResPool;

### Initialize
my $pool;
my (%datatype_pool, %datatype_maxsize);
my $psz = "$ENV{'HOME'}/trmm_data_mining/grancentral/pool_size.db";
my ($b_avail_space, $datatype);
my $wait_for_disk = 300;
         :
         :
#    Do some stuff
         :
         :
### Read the configuration file used in determining the pool
### location for the input datatype and the datatypes maximum size.
my $string = S4P::read_file("$ENV{'HOME'}/trmm_data_mining/etc/DMrespool.cfg");
exit 1 if ! $string;
eval ($string);
S4P::perish(1, "eval: $@\n"), if $@;
         :
         :
#    Do some stuff (like read work order and determine the number of files)
         :
         :
### Determine disk space required, pool location and available file space.
   my $total_req_size = $datatype_maxsize{$datatype} * $file_count;
   $pool = $datatype_pool{$datatype};

    $b_avail_space = S4P::ResPool::read_from_pool ($pool, $psz);

### Check to see if there is enough space in the pool.
### If there is, update the pool amount.
### If not, sleep until space becomes available.

   until (
          $total_req_size < $b_avail_space
          ) 
          {
            S4P::logger("WARNING",
                 "Disk space: $b_avail_space.
                        $datatype requires: $total_req_size.");
            sleep ( 5 * 60 );
            $b_avail_space = S4P::ResPool::read_from_pool ($pool, $psz);
           }
    $b_avail_space = $b_avail_space - $total_req_size;
    S4P::ResPool::write_to_pool($pool, $b_avail_space, $psz);
}
         :
         :
#   Do more stuff
         :
         :

=head1 EXAMPLE 2

Or use update_pool...

### Determine disk space required and pool location. 
my $total_req_size = $datatype_maxsize{$datatype} * $files_to_process;
$pool = $datatype_pool{$datatype};

### Update the pool amount.
### If there is not enough space, sleep until space becomes available.

do {
    $space = S4P::ResPool::update_pool ($pool, -1*$total_req_size, $psz);
    if( $space == 0 ) {
      S4P::logger("WARNING",
            "Disk space low. $datatype requires: $total_req_size.");
      sleep ( $wait_for_disk );
     }
} until $space != 0;

S4P::logger ("INFO", "$total_req_size bytes allocated.");

=head1 AUTHOR

Bob Mack, NASA/GSFC, Code 610.2

=cut

################################################################################
# ResPool.pm,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P::ResPool;
use strict;
use S4P;
use DB_File;
use Safe;
BEGIN {require DB_File::Lock if ($^O =~ /Win32/i);}
1;

sub LOCK_SH { 1 }
sub LOCK_EX { 2 }
sub LOCK_NB { 4 }
sub LOCK_UN { 8 }

#############################################################
#
### read_from_pool ##########
#
#  Input:
#    pool     directory location of the pool
#    psz      resource pool database pathname
#
#  Output:
#    size     disk space available in the pool
#
# Log:
#    05/25/00  Bob Mack, 610.2      Original development
#    06/14/00  Bob Mack, 610.2      Changed routine name
#    11/02/04  Chris Lynnes, 610.2  Modifications for Windows
# 
######################

sub read_from_pool {
    my $pool = $_[0];
    my $psz = $_[1];

    my %pool_size;
    my ($db, $fd);
    my $size;

    S4P::perish(2, "Cannot find database file $psz\n") unless (-f $psz);

    if ($^O =~ /Win32/i) {
        $db = tie (%pool_size, "DB_File::Lock", $psz, O_RDONLY, 0444, $DB_HASH, "read");
    }
    else {
        $db = tie (%pool_size, "DB_File", $psz)
            or S4P::perish (1, "Can't open $psz:$!");
        $fd = $db->fd;
        open (DB_FH, "+<&=$fd") or S4P::perish(1, "dup $!");

        unless (flock (DB_FH, LOCK_SH | LOCK_NB)) {
            S4P::logger ("WARNING", "$$: CONTENTION; can't read during write update!
                  Waiting for read lock ($!) ....");
            unless (flock (DB_FH, LOCK_SH)) {S4P::perish(1, "flock: $!");}
        }
    }

    $size = $pool_size {$pool};

    flock (DB_FH, LOCK_UN) unless ($^O =~ /Win32/i);
    undef $db;
    untie %pool_size;
    close (DB_FH) unless ($^O =~ /Win32/i); # Probably unnecessary...

    return $size;
}

#############################################################
#
### update_pool ##########
#
#  Input:
#    pool     directory location of the pool
#    size     disk pool space requested
#    psz      pathname for pool dbm file
#
#  Output:
#    transaction_size     transacted pool disk space
#
# Log:
#    07/28/00    Bob Mack, 610.2    Original Development
# 
######################
sub update_pool {
    my $pool = $_[0];
    my $size = $_[1];
    my $psz = $_[2];

    my %pool_size;
    my ($transaction_size, $current_size, $update_size);
    my ($db, $fd);

    if ($^O =~ /Win32/i) {
        $db = tie(%pool_size, "DB_File::Lock", $psz, O_CREAT|O_RDWR, 0666, $DB_HASH, "write");
    }
    else {
        $db = tie (%pool_size, "DB_File", $psz)
            or S4P::perish (1, "Can't open $psz:$!");
         $fd = $db->fd;
         open (DB_FH, "+<&=$fd") or 
             S4P::perish(1, "Failed to open file handle on $psz: $!");
         unless (flock (DB_FH, LOCK_EX | LOCK_NB)) {
             S4P::logger("WARNINIG", "$$: CONTENTION; must have exclusive lock!
                         Waiting for write lock ($!) ....");
             unless (flock (DB_FH, LOCK_EX)) {S4P::perish(1, "flock: $!");}
        }
    }

    $current_size = $pool_size {$pool};

    if ($size < 0) {      #must be an allocate
    
        if ( $current_size >= abs($size) ) {
            $update_size = $current_size + $size;
            $pool_size {$pool} = $update_size;
            $transaction_size = $size;
            $db->sync;
        }
        else {
            $transaction_size = 0;
        }
    }
    else {               # must be a deallocate
        $update_size = $current_size + $size;
        $pool_size {$pool} = $update_size;
        $transaction_size = $size;
        $db->sync;
    }

    flock (DB_FH, LOCK_UN) unless ($^O =~ /Win32/i);
    undef $db;
    untie %pool_size;
    close (DB_FH) unless ($^O =~ /Win32/i);  #Probably unnecessary...
    return $transaction_size;
}

#############################################################
#
### write_to_pool ##########
#
#  Input:
#    pool     directory location of the pool
#    size     disk space size to write to the pool
#    psz      pathname for pool dbm file
#    init     initalize hash before writing values
#             (used by create_pools)
#
#  Output:
#     None.
#
# Log:
#    05/25/00    Bob Mack, 610.2    Original development
#    06/14/00    Bob Mack, 610.2    Changed routine name
# 
######################
sub write_to_pool {
    my ($pool, $size, $psz, $init) = @_;

    my %pool_size;
    my ($db, $fd);

    if ($^O =~ /Win32/i) {
        $db = tie(%pool_size, "DB_File::Lock", $psz, O_CREAT|O_RDWR, 0666, $DB_HASH, "write");
    }
    else {
        $db = tie (%pool_size, "DB_File", $psz) or S4P::perish (1, "Can't open $psz:$!");
        $fd = $db->fd;
        open (DB_FH, "+<&=$fd") or S4P::perish(1, "dup $!");

        unless (flock (DB_FH, LOCK_EX | LOCK_NB)) {
            S4P::logger("WARNINIG", "$$: CONTENTION; must have exclusive lock!
                  Waiting for write lock ($!) ....");
            unless (flock (DB_FH, LOCK_EX)) {S4P::perish(1, "flock: $!");}
        }
    }

    %pool_size = () if $init;
    if (ref $pool && ref $size) {
            
        my $n = scalar(@$pool);
        my $i;
        for ($i = 0; $i < $n; $i++) {
            $pool_size{$pool->[$i]} = $size->[$i];
        }
    }
    else {
        $pool_size {$pool} = $size;
    }
    $db->sync;

    flock (DB_FH, LOCK_UN) unless ($^O =~ /Win32/i);
    undef $db;
    untie %pool_size;
    close (DB_FH) unless ($^O =~ /Win32/i);
    return 1;
}

#############################################################
#
### ls_pool ##########
#
#  Input:
#    psz      pathname for pool dbm file
#
#  Output:
#    pcontents   String containing pool contents
#
# Log:
#    06/08/00    Bob Mack, 610.2    Original development
# 
######################
sub ls_pool {
    my $psz = $_[0];

    my $pcontents = '';
    my ($db, $fd);
    my %pool_size;

    if ($^O =~ /Win32/i) {
        $db = tie (%pool_size, "DB_File::Lock", $psz, O_RDONLY, 0444, $DB_HASH, "read");
    }
    else {
        $db = tie (%pool_size, "DB_File", $psz) or 
           S4P::perish (1, "Can't open $psz: $!");
        $fd = $db->fd;
        open (DB_FH, "+<&=$fd") or S4P::perish(1, "Failed to open file handle on $psz: $!");

        unless (flock (DB_FH, LOCK_SH | LOCK_NB)) {
            S4P::logger ("WARNING", "$$: CONTENTION; can't read during write update!
                  Waiting for read lock ($!) ....");
            unless (flock (DB_FH, LOCK_SH)) {S4P::perish(1, "Failed to lock file handle on $psz:: $!");}
        }
    }

    foreach my $key (keys (%pool_size)) {
       $pcontents = ($pcontents . $key . " $pool_size{$key} bytes\n");
    }

    flock (DB_FH, LOCK_UN) unless ($^O =~ /Win32/i);
    undef $db;
    untie %pool_size;
    close (DB_FH) unless ($^O =~ /Win32/i);

    return $pcontents;
}
sub create_pools {
    my ($cfg_file, $db_file) = @_;

    my $cpt = Safe->new('POOL');
    $cpt->share('%pool_size');
    $cpt->rdo($cfg_file) or warn "Safe cannot parse $cfg_file: $!";
    # Split hash up into pair of arrays
    # Klunky, yes, but preserves backward compatibility in write_to_pool()
    my (@pools, @sizes);
    foreach my $pool(keys %POOL::pool_size) {
        push @pools, $pool;
        push @sizes, $POOL::pool_size{$pool};
    }
    return write_to_pool(\@pools, \@sizes, $db_file, 1);
}
