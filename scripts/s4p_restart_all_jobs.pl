#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

s4p_restart_all_jobs.pl - restart all failed jobs in a station

=head1 SYNOPSIS

s4p_restart_all_jobs.pl [command]

=head1 DESCRIPTION

This is a simple script that runs restart_job.pl and remove_job.pl in all
failed job directories under a particular station directory.  Optionally,
it will execute whatever command is specified on the command line in each
failed job directory; this allows station-specific failure handlers (e.g.,
S4PA::Receiving::FailureHandler) to be executed.

It must be run from within the station directory.

Monitor(3), tkstations(1)

=head1 AUTHOR

Stephen Berrick, NASA/GSFC, Code 610.2

=cut

################################################################################
# s4p_restart_all_jobs.pl,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use S4P;
use Cwd;
use strict;

my $pwd = cwd();
my $cmd = shift || "restart_job.pl && remove_job.pl" ;

opendir(DIR, $pwd) or S4P::perish(10, "$0: Failed to opendir $pwd: $!");

my $file;
while ( defined($file = readdir(DIR)) ) {
    if ( -d $file and $file =~ /^FAILED\./ ) {
        chdir($file);
        my ($rs, $rc) = S4P::exec_system($cmd);
        chdir($pwd);
    }
}

