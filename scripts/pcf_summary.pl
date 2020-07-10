#!/usr/bin/perl

=head1 NAME

pcf_summary - print out summary of PCF with full pathnames

=head1 SYNOPSIS

pcf_summary.pl pcf_file

=head1 DESCRIPTION

This goes through a PCF, discards comments and puts together paths for the
various file types in a human readable form. 
(It does not yet print runtime parameters.)

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# pcf_summary.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use S4P::PCF;
use S4P::PCFEntry;
$pcf = S4P::PCF::read_pcf($ARGV[0]);
$pcf->read_file;
$pcf->parse;
$r_logfiles = $pcf->log_files;
%logfiles = %{$r_logfiles};
print "Logfiles:\n";
foreach $f(sort keys %logfiles) {
    print "    $f:    $logfiles{$f}\n";
}
print "Product Input:\n";
print "    Data Files:\n";
%files = %{$pcf->input_data_files};
foreach $f(sort keys %files) {
    print "        $f: $files{$f}\n";
}
print "Product Output:\n";
print "    Data Files:\n";
%files = %{$pcf->output_data_files};
foreach $f(sort keys %files) {
    print "        $f: $files{$f}\n";
}
print "    Metadata Files:\n";
%files = %{$pcf->output_met_files};
foreach $f(sort keys %files) {
    print "        $f: $files{$f}\n";
}
