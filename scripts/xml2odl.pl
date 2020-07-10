#!/usr/bin/perl

=head1 NAME

xml2odl - convert XML metadata to ODL metadata file

=head1 SYNOPSIS

xml2odl xml_file

=head1 DESCRIPTION

Converts an XML style Data Pool metadata file to ODL (.met) metadata.

=head1 AUTHOR

Christopher Lynnes, NASA/GSFC, Code 610.2

=head1 BUGS

Does not include dataset-level metadata.

=cut

################################################################################
# xml2odl.pl,v 1.2 2006/09/12 19:43:50 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use S4P::MetFile;
my $file = shift @ARGV;
open F, $file or die "Cannot open $file: $!\n";
$/ = undef;
my $xml = <F>;
close F;
my $odl = S4P::MetFile::xml2odl($xml);
print "$odl";
exit(0);
