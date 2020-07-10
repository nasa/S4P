#! /tools/gdaac/COTS/bin/perl

=head1 NAME

s4p_pdr_fetch.pl - Simple script to fetch files referenced in a PDR

=head1 SYNOPSIS

s4p_pdr_fetch.pl 
[B<-d> I<data_dir>]
[B<-o> I<pdr_dir>]
PDR_file

=head1 DESCRIPTION

This script fetches the files in a PDR using the ftp_get method if it
is remote, or the symlinks method if it is local.
It bases this decision on the hostname: if it matches that in the PDR it
will use the symlink method.  (Use "localhost" to force FTP get on a local
machine.)

The default target data directory is the current one, but can be overriden 
with the -d option.

There is also an option to output a PDR with the local directory and hostname
in place of the remote one. This will have the filename pattern:
  <originating_system>.<localtime>_<pid>.pdr

=head1 ARGUMENTS

=over 4

=item B<-d> I<dir>

Local directory in which to put the files (or links).

=item B<-o> I<dir>

Directory in which to put an output PDR describing the new location of
the files.  This will have the pattern <orig_system>.<time>_<pid>.pdr.

=back

=head1 AUTHOR

Christopher Lynnes, NASA/GSFC

=cut

################################################################################
# s4p_pdr_fetch.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use Getopt::Std;
use Cwd 'realpath';
use S4P::PDR;

# Parse command line
use vars qw($opt_d $opt_h $opt_o);
getopts('d:ho:');
usage() if $opt_h;
my $dir = $opt_d || '.';
my $realdir = realpath($dir);
S4P::logger("INFO", "Realpath for $dir is $realdir");

# Read in PDR
my $pdr_file = shift(@ARGV) or usage();
my $pdr = S4P::PDR::read_pdr($pdr_file) or die "Cannot read/parse $pdr_file\n";

# See if we are local or remote
my @new_fg;
if (local_or_remote($pdr)) {
    @new_fg = map {$_->symlinks($realdir)} @{$pdr->file_groups};
    S4P::perish(10, "Failed to create symlinks") unless @new_fg;
}
else {
    my ($success, $ng) = $pdr->ftp_get($realdir, 1, 0);
    print "$ng file_groups retrieved\n";
    die ("Failed to retrieve some file_groups\n") unless ($success);
    @new_fg = map {$_->copy} @{$pdr->file_groups};
    my $here = S4P::PDR::gethost();
    foreach my $fg(@new_fg) {
        map {$_->directory_id($realdir)} @{$fg->file_specs};
        $fg->node_name($here);
    }
}
if ($opt_o) {
    my $new_pdr = $pdr->copy();
    $new_pdr->file_groups(\@new_fg);
    my $base = $new_pdr->originating_system;
    $base =~ s/\s+/_/g;
    my $filename = sprintf("%s/%s.%d_%d.pdr", $opt_o, $base, time(), $$);
    # Write PDR; (don't forget about funky error code reversal)
    if ($new_pdr->write_pdr($filename) == 0) {
        S4P::logger("INFO", "Wrote output PDR to $filename");
    }
    else {
        S4P::logger("ERROR", "Failed to write output PDR to $filename: $!");
        exit(11);
    }
}
exit(0);

sub local_or_remote {
    my $pdr = shift;
    my $here = S4P::PDR::gethost();
    foreach my $fg (@{$pdr->file_groups}) {
        my $node_name = $fg->node_name;
        return 0 if ($node_name ne $here);
    }
    return 1;   # Got all the way through: must be local
}
sub usage { die "$0 [-d directory] [-o directory] PDR\n"; }
