#!/usr/bin/perl

=head1 NAME

s4p_repeat_work_order - copy an input work order to an output work order

=head1 SYNOPSIS

s4p_repeat_work_order.pl 
B<[-l]> 
B<[-r]> 
B<[-R]> 
[B<-s> I<suffix>] 
[command] [args] INPUT_WORK_ORDER

=head1 DESCRIPTION

B<s4p_repeat_work_order.pl> copies an input work order to an output work order.
It assumes the default pattern (i.e., "DO.job_type.job_id.wo").
In other words, it copies DO.JOB_TYPE.OLD_JOB_ID to 
JOB_TYPE.NEW_JOB_ID.wo

It will keep the same job_type, but construct a unique job_id consisting
of the time and the process_id.

It's purpose is for repeater stations, which act like cron to continually
execute the same command but without a data-driven input, other than a seed
file.

=head1 OPTIONS

=over 4

=item B<-l>

Keep the log file from the previous cycle.
The default is to discard the log file from the previous cycle.

=item B<-r>

Retry:  repeats the work order only if the exit code of the child is non-zero.
Exit code of zero results in no repeat.

=item B<-R> I<exit_code>

Retry:  repeats the work order only if the exit code matches a specified one.
Exit code of anything else results in no repeat.

=item B<-s>

Suffix to add at the end of the work order.  Default is 'wo'.

=back

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# s4p_repeat_work_order.pl,v 1.3 2008/06/03 20:04:17 lynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use Getopt::Std;
use S4P;
use strict;
require 5.6.0;

use vars qw($opt_l $opt_r $opt_R $opt_s);

getopts('lrs:R:');

if (! $opt_l) {
    # First order of business:  truncate the existing log file so it doesn't
    # grow indefinitely
#    my ($log) = glob('*.log');
#    truncate($log, 0);
    truncate(STDERR, 0);
    seek STDERR, 0, 0;
    seek STDOUT, 0, 0;
}

# Separate work order from command, command from args
my $work_order = pop(@ARGV);
my $command = shift(@ARGV);

# Execute command
my ($error_string, $errcode);
if ($command) {
    my $cmd_string = join(' ', $command, @ARGV, $work_order);
    S4P::logger("INFO", "Executing $cmd_string");
    ($error_string, $errcode) = S4P::exec_system($cmd_string);
    $error_string = 'Success' if ($errcode == 0);
    S4P::logger("INFO", "Exit Code: $errcode, Result: $error_string");
}
# RETRY mode:  repeat work order only for non-zero exit code
if ($opt_r) {
    exit ($errcode ? (! S4P::repeat_work_order($work_order, $opt_s)) : 0);
}
elsif ($opt_R) {
    exit ( ($errcode == $opt_R) ? (! S4P::repeat_work_order($work_order, $opt_s)) : $errcode);
}
elsif ($errcode) {
#    S4P::perish($errcode, "System command $command failed");
    S4P::perish(1, "System command $command failed with status $errcode");
}
else {
    exit (! S4P::repeat_work_order($work_order, $opt_s));
}
