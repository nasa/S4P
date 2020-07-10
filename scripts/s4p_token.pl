#!/usr/bin/perl

=head1 NAME

s4p_token.pl - manage run tokens in a tokenmaster station

=head1 SYNOPSIS

s4p_token.pl 
[B<-w> I<$wait>]
[B<-i> I<$interval>]
work_order

=head1 DESCRIPTION

This program is run as a station script in a tokenmaster station.
It responds to requests for tokens by renaming them.
It then polls for the existence of the token file, and when gone,
exits 0.
If it times out with the file still in existence, it exits 2.

=head1 FILES

Like any other station, the tokenmaster station needs a I<station.cfg> file.
The only requirement imposed on the station configuration is that the
B<%cfg_commands> variable recognize the incoming work order job types, i.e.,
TOKEN.

Thus, we have:
  %cfg_commands = (
    'TOKEN' => 's4p_token.pl'
  );

No B<%cfg_downstream> variable is required.

Sorting, max_children, max_jobtime can be set up in any manner desired,
though FIFO sorting is probably the best default.
The last part of the job_id is a 32-bit checksum of the token requestor's 
station directory path, so a station-specific sort routine could be 
substituted that favors one station's requests over anothers.

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2.

=cut

use S4P;
use Getopt::Std;
use strict;
use vars qw($opt_w $opt_i);

my $wait = $opt_w || (3600 * 24);
my $interval = $opt_i || 5;

# Get id from work order
my $work_order = pop @ARGV;
my $token = S4P::grant_token($work_order) or 
    S4P::perish(2, "Failed to grant token to work order $work_order");;
if ( S4P::await($wait, $interval, "Waiting for job $token to finish", 
    sub {return (! (-f $token))}) ) 
{
    exit(0);
}
else {
    S4P::logger('ERROR', "Timed out after $wait waiting for $token to finish");
    exit(2);
}

