#!/usr/bin/perl

=head1 NAME

s4p_subscribe - station script to invoke S4P::Subscription::fill_subscriptions

=head1 SYNOPSIS

s4p_subscribe [B<-f> I<subscription_file>] [B<-v>] [B<-d> I<PDR queue>] [pdr_work_order]

=head1 DESCRIPTION

s4p_subscribe.pl reads a PDR file and passes it to 
S4P::Subscription::fill_subscriptions.
It also moves the input work order to an output work order.

=head1 ARGUMENTS

=over 4

=item B<-f> I<subscription_file>

Configuration file  with subscriptions.  See Subscription(3) man page for
more details on format.  Default is '../subscriptions.cfg'.

=item B<-d> I<PDR queue>

Directory containing PDRs to be processed. If a queue is not specified, a
PDR must be specified as work order.

=item B<-v>

Verbose flag.

=back

=head1 SEE ALSO

Subscription(3)

=head1 AUTHOR

Christopher Lynnes, NASA/GSFC, Code 610.2

=head1 LAST REVISED

2004/08/16, 16:44:52

=cut

################################################################################
# s4p_subscribe.pl,v 1.2 2006/09/12 19:43:50 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use vars qw($opt_f $opt_v $opt_d);
use Getopt::Std;
use S4P::PDR;
use S4P;
use S4P::Subscription;

getopts('d:f:v');
usage() unless @ARGV;

# (1) Set subscription file
my $subscription_file = $opt_f || '../subscriptions.cfg';
S4P::perish(2, "Cannot find subscription file $subscription_file")
    unless(-f $subscription_file);

my $pdr;
my @pdrFileList;
if ( defined $opt_d ) {
    # (2) Monitor a queue for PDRs
    local( *DH );
    opendir( DH, $opt_d ) || S4P::perish(2, "Failed to open $opt_d ($!)" );
    @pdrFileList = grep( /PDR$/, readdir(DH) );
    closedir( DH );
    @pdrFileList = map( "$opt_d/$_", @pdrFileList ) if @pdrFileList;    
    foreach my $pdrFile ( @pdrFileList ) {
        my $dummyPdr = S4P::PDR::read_pdr( $pdrFile )
            || S4P::perish( 2, "Cannot read/parser PDR $pdrFile" );
        if ( defined $pdr ) {
            foreach my $fileGroup ( @{$dummyPdr->file_groups()} ) {
                $pdr->add_file_group( $fileGroup );
            }    
        } else {
            $pdr = $dummyPdr;
        }    
    }
} else {
    # (2) Read work order
    $pdr = S4P::PDR::read_pdr($ARGV[0]) or
        S4P::perish(2, "Cannot read / parse PDR work order $ARGV[0]");
}

if ( $pdr ) {
    # (3) Fill subscriptions
    S4P::Subscription::fill_subscriptions($subscription_file, $pdr, $opt_v) or
        S4P::perish(3, "Failed to fill subscriptions");
    # Cleanup PDRs picked up from the PDR queue
    foreach my $file ( @pdrFileList ) {
        unlink( $file ) || S4P::perish( 2, "Failed to remove $file ($!)" );
    }
}


exit(0);

sub usage {
    die "Usage: $0 [-f subscription_file] [-d PDR_queue] [-v] pdr_work_order";
}
