#! /tools/gdaac/COTS/bin/perl

=head1 NAME

s4p_mk_pdr.pl - Simple script to generate PDRs

=head1 SYNOPSIS

s4p_mk_pdr.pl 
[B<-e> I<days>]
[B<-o> I<orig_system>]
[B<-n> I<node_name>]
data_file data_file ...
> PDR_file

=head1 DESCRIPTION

This script generates a PDR based on one or more science data files
and writes it to STDOUT.
It assumes that there is a metadata file with either a .met or .xml
extension sitting right alongside it.

=head1 ARGUMENTS

=over 4

=item B<-e> I<days>

Expiration time in days (default = 3).

=item B<-o> I<orig_system>

Originating system (default is S4P).

=item B<-n> I<node_name>

Override node_name default (obtained from gethostbyname).
For example, to get g0dup05u.ecs.nasa.gov instead of
g0dup05.gsfcb.ecs.nasa.gov (the default).

=back

=head1 AUTHOR

Christopher Lynnes, NASA/GSFC

=cut
 
################################################################################
# s4p_mk_pdr.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use File::Basename;
use Getopt::Std;
use Cwd;
use S4P::PDR;
use S4P::MetFile;

use vars qw($opt_o, $opt_e $opt_n);
getopts('e:n:o:');
usage() unless @ARGV;
my $exp_days = $opt_e || 3;
my $exp_time = S4P::PDR::get_exp_time($exp_days, 'days');
my $orig_system = $opt_o || 'S4P';
my $pdr = S4P::PDR::start_pdr('originating_system'=>$orig_system,
    'expiration_time' => $exp_time);
my $node_name = $opt_n || S4P::PDR::gethost();

foreach my $scifile(@ARGV) {
    die "Cannot find $scifile" unless -f $scifile;

    # Form Metfile name from Science file
    my $metfile = "$scifile.met";
    unless (-f $metfile) {
        $metfile = "$scifile.xml";
    }
    die "Cannot find $metfile" unless -f $metfile;
    my $dir = dirname($scifile);
    $cwd = getcwd();
    if ($dir) {
        chdir $dir or die "Cannot chdir to $dir: $!";
        $dir = getcwd();
        chdir $cwd or die "Cannot chdir back to $cwd: $!";
    }
    else {
        $dir = $cwd;
    }
    my %met = S4P::MetFile::get_from_met($metfile,'SHORTNAME','VERSIONID');
    my $esdt = $met{'SHORTNAME'} or die "No SHORTNAME in $metfile";
    my $version = $met{'VERSIONID'} or die "No VERSIONID in $metfile";

    my @files = ($scifile, $metfile);
    my $file_group = $pdr->add_granule(
                                'node_name'=>$node_name,
                                'data_type'=>$esdt,
                                'data_version'=>$version,
                                'files'=>\@files);
}
print $pdr->sprint();

sub usage {
   die "\
Usage: s4p_mk_pdr.pl \
         [-n nodename] \
         [-o orig_system] \
         [-e expire_days] \
         data_file data_file...\n";
}
