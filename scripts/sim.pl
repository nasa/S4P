#!/usr/bin/perl

=head1 NAME

sim.pl - simulator program for S4P

=head1 SYNOPSIS

sim.pl 
B<-f> I<config_file>
B<[-v]>
B<[-s]>
[B<-F> I<failure_probability>]

=head1 DESCRIPTION

B<sim.pl> is a simulator program for S4P, used for testing both S4P and S4P 
station configurations.  It is meant to simulate an actual processing program, 
with input files and output files. 

Although it does not currently read or write such files, it does transform 
input filenames in an input work order (PDR) into output filenames for the
output work order.

It runs off a somewhat complicated configuration file (see FILES section).
It can take a number of parameters, usually in the config file, but some can
be overridden on the command line (see ARGUMENTS), such as sleep time, and the
probability for which job failures are desired (for exercising the station
monitor programs).

=head1 FILES

sim.cfg is a configuration file (actually a Perl segment) for driving sim.pl.
Its core task is to map the files referenced in the incoming work order
(structured as a PDR) to output filenames, writing an outgoing work order.
This allows construction of a simulator with many chained and branching 
stations.

The key to this is a hash, named %replace, keyed on the filename patterns in 
the input work order.  
Each such pattern can have one or more substitution functions
(in a hash, using the s/// syntax) which map the input B<work order name> 
into an equivalent output B<work order name>. This name will be the name of the 
file(s) sim.pl creates.

Each of those output work orders can have an array of substitution functions
which maps the input filenames in the "input" work order to the "output" 
filenames in the output work order.

Here is an example:

    %replace = ('bangkok_dengue.*' => 
                   {'s/IMPORT/INIT/'=>
                       ['s/bangkok_dengue/dengue_input/']
                   }
               );

The example above makes sim.pl look in an input work order named 
DO.IMPORT.<some_jobid>.wo for files named bangkok_dengue.*.  It generates
an output work order named INIT.<some_jobid>.wo, where every filename
*bangkok_dengue* is now named *dengue_input*.

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# sim.pl,v 1.2 2006/09/12 19:43:50 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

# TODO:  Add logging to log file rather than standard out

use Getopt::Std;
use Safe;
use S4P::PDR;
use strict;
use vars qw($opt_f $opt_v $opt_s $opt_F);

$|=1;
print "Starting sim.pl...\n";
getopts('f:vs:F:');
my (%replace, $sleep);

# Read in configuration file
my $compartment = new Safe 'CFG';
$compartment->share('%replace','$sleep');
$compartment->rdo($opt_f) or die "Cannot read config file $opt_f in safe mode: $!\n";
print "Read config file $opt_f.\n";
$main::sleep ||= $opt_s;  # override if on command line

my $failure_prob = $opt_F || 0;  # override if on command line
print "Failure probability = $failure_prob.\n";

# Read in and parse work order file
undef $/;
my $pdr = new S4P::PDR('text' => S4P::read_file($ARGV[0]));
exit 1 if ! $pdr;
my ($file_group, $r_file_specs, $file_spec);
my (@pdr_input_files);

# Collect the files from the input PDR
print "Looping through files in input PDR...\n";
foreach $file_group(@{$pdr->file_groups}) {
    $r_file_specs = $file_group->file_specs;
    foreach $file_spec(@{$r_file_specs}) {
        printf "%s (%s)\n",$file_spec->pathname,$file_spec->file_type if $opt_v;
        push @pdr_input_files, $file_spec->pathname;
    }
}
my ($infilepat, @input_files, @output_files, $work_order_file);
my ($out_wo_replace, $output_work_order, $out_file_replace);

# Loop through the input file patterns from the PDR using the regex "mask" 
# (infilepat) from the config file.
# This is the primary key for the monster hash.
foreach $infilepat (keys %main::replace) {
    print "$infilepat\n";
    # Look for input files from the PDR matching the input file pattern
    @input_files = grep /$infilepat/, @pdr_input_files;
    map {print "$_\n"} @input_files if ($opt_v);

    # Loop through the replacement patterns for creating new output work orders
    foreach $out_wo_replace(keys %{$main::replace{$infilepat}}) {
        $output_work_order = $ARGV[0];
        $output_work_order =~ s/.*?DO\.//;
        eval '$output_work_order =~ ' . $out_wo_replace;
        $output_work_order .= ".wo";
        # Loop through the replacement patterns for creating new output 
        # filenames to go in the new output work order
        foreach $out_file_replace (@{$main::replace{$infilepat}{$out_wo_replace}}){
            @output_files = @input_files;
            eval "map {$out_file_replace}".'@output_files';
            print "$out_file_replace\n" if $opt_v;
            map {print "$_\n"} @output_files if $opt_v;
            # TODO:  Copy the input files to the output files
            # TODO:  Create a new work order with the output filenames (PDR.pm)
        }
        write_output_pdr($output_work_order, 'TODO', '', @output_files);
        print "$output_work_order\n" if $opt_v;
    }
}
print "Sleeping $main::sleep seconds...\n" if $opt_v;
sleep $main::sleep;
if (rand(100) > $failure_prob) {
    exit 0;
}
else {
    print STDERR "Random failure!\n";
    exit 1;
}

sub write_output_pdr{
    my ($output_pdr, $esdt, $version, @output_files) = @_;
    my $pdr = S4P::PDR::create();
    $pdr->add_file_group($esdt, $version, @output_files);
    $pdr->write_pdr($output_pdr);
}
