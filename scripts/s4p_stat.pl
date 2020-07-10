#!/tools/gdaac/COTS/bin/perl

=head1 NAME

s4p_stat.pl - get status for multiple S4P strings and print them to STDOUT

=head1 SYNOPSIS

s4pstart.pl directory directory ...

=head1 DESCRIPTION

s4p_stat.pl is a command line program to get status for multiple S4P strings
and print them to STDOUT.  

The format of the output is:
  directory_path
    station:job_type disable n_fail_work_orders n_fail_jobs n_warn n_run n_pend
    station:job_type disable n_fail_work_orders n_fail_jobs n_warn n_run n_pend
  ...

=head1 AUTHOR

Christopher Lynnes, NASA/GSFC, Code 610.2

=head1 LAST REVISED

2006/08/07 12:23:31

=cut

################################################################################
# s4p_stat.pl,v 1.4 2007/02/09 16:38:28 lynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use vars qw($opt_f $opt_v);
use Cwd;
use Getopt::Std;
use File::Basename;

use S4P;
use S4P::StaMon;

getopts('fv');
my $fmt = $opt_f ? "%-55.55s %1d %1d %3d %3d %3d %3d %3d\n" : "Sta:%s:%d:%d:%d:%d:%d:%d:%d\n";

foreach my $dir(@ARGV) {
    my $stations = S4P::read_file("$dir/station.list");
    unless ($stations) {
        warn "Cannot read stations from $dir/station.list, skipping...\n";
        next;
    }
    print "String: $dir\n";
    foreach my $station(split(/\n/, $stations)) {
        # For absolute paths, use that; otherwise append to directory
        # where station.list was found
        my $path = ($station =~ m#^/#) ? $station : "$dir/$station";

        my $stamon = S4P::StaMon::create($path);
        print STDERR "Refreshing $path..." if $opt_v;
        $stamon->refresh('-skip_counters' => 1);
        print STDERR "Done.\n" if $opt_v;
        my $base = basename($station);
        my $header = $opt_f ? ("  $base (" . $stamon->name . '):') 
                            : join(':', $base, $stamon->name);
        printf($fmt, $header, $stamon->disable, $stamon->station_status, 
            $stamon->n_fail_work_orders, $stamon->n_fail_jobs, $stamon->n_warn,
            $stamon->n_run, $stamon->n_pend);
    }
}
