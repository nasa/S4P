#!/usr/bin/perl

=head1 NAME

replace_mode - replace occurrences of a mode with a different mode in specified files

=head1 SYNOPSIS

replace_mode.pl 
B<-o> I<old_string>
B<-n> I<new_string>
file file file...

=head1 DESCRIPTION

This is used for promoting stations from one mode to the next.  
For regular files, it replaces all references of one string with a different 
string.
For symlinks, it replaces any path elements in the symlink value, then deletes
the old symlink and creates a new one with the new symlink value.

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# replace_mode.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use Getopt::Std;
use strict;
use vars qw($opt_o $opt_n $opt_v);
getopts('n:o:v');
die "$0 -o old_string -n new_string file file file...\n" unless ($opt_o && $opt_n);
my $file;
$opt_o =~ s#^/##;
$opt_o =~ s#/$##;
$opt_n =~ s#^/##;
$opt_n =~ s#/$##;
foreach $file(@ARGV) {
    if (-f $file) {
        print "Replacing $opt_o with $opt_n in $file...\n";
        open IN, $file or die "Cannot open $file: $!\n";
        my @lines;
        while (<IN>) {
            s#(?=\W|\b)$opt_o(?=\W|\b)#$opt_n#gx;
            push(@lines, $_);
        }
        close IN;
        open OUT, ">$file" or die "Cannot open $file to modify: $!\n";
        print OUT @lines;
    }
    elsif (-l $file) {
        my $old_link = readlink($file);
        my $new_link = $old_link;
        $new_link =~ s/$opt_o/$opt_n/g;
        if ($new_link ne $old_link) {
            print "Replacing $opt_o with $opt_n in symlink path for $file...\n";
            unlink $file or die "Cannot unlink old link for $file: $!\n";
            symlink($new_link, $file) or die "Cannot symlink $file to $new_link: $!\n";
        }
    }
}
