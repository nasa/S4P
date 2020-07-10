#!/usr/bin/perl -w
########################################################################

=head1 NAME

cpooldb.pl - create the disk pool database file

=head1 SYNOPSIS

cpooldb.pl allocdisk_pool.cfg allocdisk.db 

where allocdisk_pool.cfg is the configuration file that defines 
the pool contents.

=head1 DESCRIPTION

Create the disk pool database file.
This is deprecated in favor of s4p_pooldb.pl, which 
adds update functionality.

=head1 FILES

This is an example of the allocdisk_pool.cfg configuration file contents.

$pool_size {"/vol1/data/output/MOD01/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD03/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD01SS/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD02OBC/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD021KM/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD02HKM/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD02QKM/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD021QA/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD02HQA/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD02QQA/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD02SS1/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD07_L2/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD35_L2/"} = 1000000000;
$pool_size {"/vol1/data/output/MODCSR_G/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD07_QC/"} = 1000000000;
$pool_size {"/vol1/data/output/MOD35_QC/"} = 1000000000;
$pool_size {"/vol1/data/output/MODVOLC/"} = 1000000000;

=head1 AUTHOR

Bob Mack, NASA/GSFC, Code 610.2

=cut

################################################################################
# cpooldb.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use S4P::ResPool;
die "Usage: $0 s4pm_allocdisk_pool.cfg s4pm_allocdisk.db\n" unless (scalar(@ARGV) == 2);
S4P::ResPool::create_pools($ARGV[0], $ARGV[1]);
exit(0);
