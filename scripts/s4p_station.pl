#!/usr/bin/perl -w

=head1 NAME

s4p_station.pl - runs a station within the S4P

=head1 SYNOPSIS

s4p_station.pl
[B<-d> I<directory>] 
[B<-c> I<config_file>] 
[B<-t>] 
[B<-h>] 
[B<-u> I<umask>]
[B<-s>]
[B<-1>]
[B<-C>]

=head1 ARGUMENTS

=over 4

=item B<-d> I<directory>

Directory for s4p_station to monitor.  The default is the current directory,
but it is usually helpful to specify this on the command line so that different
instances can be distinguished with the I<ps> command.

=item B<-c> I<config_file>

Configuration file to be loaded. Default is I<station.cfg>, the recommended
filename so that companion programs (e.g. tkstations.pl) can interoperate
with s4p_station.

=item B<-t>

"Tee" the logging to standard error in addition to the station.log file.

=item B<-h>

Print a usage message and exit.

=item B<-u> I<umask>

Umask for s4p_station to run with.  Default is 002 (group-writable).
Example:  I<s4p_station -u 022> will set it the umask to 022. Note the
specification in octal.

=item B<-s>

Flag to turn on the statistics logging. This will create a file called
station.stats in the station root directory. This will be in the format:

 AVERAGE EXECUTION TIME
 NUMBER OF EXECUTIONS
 TOTAL EXECUTION TIME

This is mainly for use with the S4P Router, but it may be useful otherwise.

Added by Judd Taylor, USF Institute for Marine Remote Sensing, July 16,
2002.

=item B<-1>

Just run one job and quit. (Useful for testing.)

=item B<-C>

"Classic" mode (deprecated).  Execs stationmaster.pl instead.
N.B.:  stationmaster.pl is expected to be in the same directory as 
s4p_station.pl.

=back

=head1 DESCRIPTION

statationmaster looks for incoming "work orders" and runs a program or
Perl module appropriate to the file name of the work order.

=head1 FILES

=over 4

=item DO.<jobtype>.<jobid>.wo 

Input work order file to be worked on

=item DO.STOP.*.wo

Special work order causes the station to stop itself the next time
it polls.

=item DO.RESTART.*.wo

Special work order causes the station to stop and restart itself the 
next time it polls.

=item DO.RECONFIG.*.wo

Special work order causes the station to reread the station.cfg file
the next time it polls.

=item DO.VANISH.*.wo

Special work order causes the station to stop and delete itself.
Will only happen if station has been configured accordingly
(with $cfg_vanishing set to a non-zero value).

=item PRI*.DO.<jobtype>.<jobid>.wo

High-priority input work order file to be worked on.  These are processed
before the regular work order files.  Downstream jobs inherit the same
priority (i.e., they have the PRI* prefix prepended to their job names.

=item REDO.<jobtype>.<jobid>.wo 

work order retry file.  This is deprecated (and may not even work).

=item <jobtype>.<jobid>.wo

output work order file

=item station.cfg

configuration file for a given station

=item station.log

log file for that station

=item station_counter.log

simplified log file showing job starts and stops

=back

=head1 CONFIGURATION

=over 4

=item %cfg_commands=($file_part=>command,file_part=>package::function...)

This maps the second part of the input work order filename (after DO.) to 
the command or Perl function to be run.
For example, if the file is DO.RUNPGE02.19981231.wo, the code looks for 
$cfg_commands{'RUNPGE02'}.

Perl-like regular expressions can also be used, or at least the characters 
C<.*^$>.
This is particularly useful for "foreign" work orders, like PDRs or metadata
(.met) files from the EOSDIS Core System.  
However, the pattern matching in $cfg_work_order_pattern is of the Unix-like 
glob type, not a Perl regular expression.

If you do use this feature, the job_id will comprise the whole file name;
any suffix will not be "popped" off as it is for normal work orders.

WARNING:  be careful with this feature.  It is all too easy to have two
regular expressions match on a given string.  In this case, the code will use
the first one it finds, which may not be the one you expect.

=item %cfg_downstream = ($file_part => [station, station, ...])

This maps the second part of the output work order filename (after DO.) to 
the downstream stations where the file is supposed to be sent.

=item $cfg_failed_work_order_dir = directory

Directory in which failed work orders are placed (default = FAILED.WORK_ORDERS)

=item $cfg_logfile = logfile

The log file to write output to (default = station.log).

=item $cfg_counter_logfile = logfile

The log file to write output to (default = station_counter.log).

=item $cfg_max_children = n

The maximum number of children that can be forked.  
This is a simple way of adjusting the children to the temporary resources
(e.g. temporary disk) available.  
Setting this to 1 essentially makes the station single-threaded.
This includes only running children, not failed children.
Default is 5.

This can also be an anonymous hash, keyed on job_type.  In this case, it
will stop processing those job_types that have reached their max_failures
threshold, but continue processing other job_types, e.g.:

  $cfg_max_failures = { 'ABLE' => 2 };

This will stop processing ABLE work orders when 2 ABLE failures are sitting
there, but keep processing other work orders.  

=item $cfg_max_failures = n

The maximum number of failed jobs that can pile up before the station stops.
This counts the number of FAILED.* directories.
Failed work orders (those that never even execute) are not included.
Default is undef (i.e., infinite).

=item $cfg_polling_interval = n seconds

The number of seconds between polls of the station directory to
look for new work orders.  Default = 10 seconds.

=item $cfg_stop_interval = n seconds

The number of seconds between polls of the station directory to
look for a STOP work order.  Default is the same as $cfg_polling_interval.

=item $cfg_stop_interval = n seconds

The number of seconds between polls of the station directory to
look for a STOP work order.  Default is the same as $cfg_polling_interval.

=item $cfg_end_job_interval = n seconds

The number of seconds between polls of the child s4p_station
look for the signal files END_JOB_NOW, SUSPEND_JOB_NOW and RESUME_JOB_NOW.  
Default is undefined unless $cfg_group is set, 
in which case this will be the same as $cfg_stop_interval.
(If it is undefined, s4p_station will not look for these files at all.)

=item $cfg_deadline = n seconds

The number of seconds beyond which s4p_station will end the process 
it is running.  Default is undefined, meaning no deadline.

=item $cfg_child_sleep = n seconds

(Deprecated.) Number of seconds the child sleeps before starting. Default = 0.

=item $cfg_root

The root directory for downstream stations.

=item $cfg_sort_jobs

Order in which to execute work orders in a given time interval.  This causes
the jobs to be sorted according to the algorithm specified:

=over 4

=item $cfg_sort_jobs = 'FIFO';

Executes the jobs in a first-in-first-out order.

=item $cfg_sort_jobs = ['job_type1', 'job_type2',...];

Executes the jobs as specified in the anonymous array.

=item $cfg_sort_jobs = "MySort::sort_function";

This allows a station-specific sort function to be specified.
Simply put a module in the station directory (e.g. MySort.pm)
with a function to do the sorting the way I<you> want it to work.
Note that since this package is different from s4p_station.pl, the
arguments $a and $b should be prototyped, e.g.:
  sub by_strlen($$) {
    my ($a, $b) = @_;
    ...

=back

Note that the high priority jobs will be executed before the regular jobs
in any case.

=item %cfg_reservations

Allows reservations for particular job types.
The key of the hash is the job type and the value is the number of reserved 
job "slots" for that job type:
  %cfg_reservations = ('ALLOCATE_MoPGE01' => 1, 'ALLOCATE_MoPGE02' => 5);

If max_children is greater than the total number of reservations, "walk-ins"
will be accepted for the extra slots.
If some job types do not have reservations, they can ONLY get walk-in slots.

B<N.B.:  Make sure that max_children is greater than or equal to the total 
number of reservations.>

=item %cfg_token

For a given job_type, lists the directory of the tokenmaster station.
When this is set, the job will be spawned but will not begin executing
until it receives a token from the tokenmaster station.

=item $cfg_user

Username under which s4p_station should be started up.
Stationmaster will fail if user starting it up does not match this user.
This is not for security purposes, just to prevent permission confusion.

=item $cfg_host

Host on which s4p_station should be started up. Stationmaster will fail
if the host machine on which the station is being started does not match
$cfg_host.

=item $cfg_input_work_order_suffix

The suffix used to identify incoming work orders.  
Default is $S4P::work_order_suffix

=item $cfg_output_work_order_suffix

The suffix used to identify outgoing work orders.  
Default is $S4P::work_order_suffix.
This has special behavior if this variable is set to 'log'.
In this case, the log file is the same as the output work order, and only
the output work order will be moved downstream, to avoid unnecessary 
duplication.

=item $cfg_work_order_pattern

This is a glob pattern (not a regular expression pattern) which can be used 
instead of $cfg_input_work_order_suffix to specify a the whole
work order pattern, overriding the normal DO. prefix.  This is useful for 
stations that are detecting "foreign" work orders that don't follow S4P naming
conventions.

=item $cfg_ignore_duplicates

Tells s4p_station to ignore cases where duplicate work orders have apparently
been sent to a station.  This can appear to happen when file system response
times exceed the polling interval.

=item $cfg_ignore_empty_files

Tells s4p_station to ignore cases where the work order file is empty.
This can happen when file system response times are slow, causing the inode
to appear before the contents.
I<N.B.:  some work orders really ARE zero-length, so use this carefully.>

=item $cfg_restart_defunct_jobs

If set, this will check for defunct jobs on startup:  cases where the job
is dead, but the directory name and job_status still indicate RUNNING.

=item $cfg_rename_retries, $cfg_rename_retry_interval

Parameters that allow s4p_station to make another try at renaming
a RUNNING directory to a FAILED directory.  This is intended to get around
cases where the rename fails but may succeed in a little bit, such as when
Windows holds onto files in the directory a little too long.

$cfg_rename_retries defaults to 0 (i.e., tries only once).
$cfg_rename_retry_interval defaults to 5 seconds.

=item $cfg_case_log

File to log errors in for case-based reasoning purposes.

=item %cfg_virtual_jobs

Sets up "virtual" work orders, aka self-seeding recycling work orders.
It is a hash whose key is JOB_TYPE and value is the number to keep
in the pipeline.  For example, setting:

  %cfg_virtual_jobs = ('FOOBAR' => 2);

will cause s4p_station to:

(1) See if the total number of pending and running FOOBAR jobs is less than 2.
If $cfg_virtual_feedback is set to non-zero, failed jobs are also included in
the count.

(2) Write short files of type DO.<job_type>.<time><nnn>.<suffix> until there are 2

Note that if you use this, there is no need to have your script create an output
work order for recycling.

=item $cfg_virtual_feedback

Include failed jobs when counting up current jobs for a given type.

=item $cfg_max_interval

This is the maximum expected time in seconds between arrival of jobs 
(other than STOP, RECONFIG or RESTART jobs). If no jobs are received in
that interval, an anomaly (TOO_QUIET) is raised.

=back

=head1 ENVIRONMENT VARIABLES

=over 4

=item OUTPUT_DEBUG

If set to 1, this causes DEBUG type messages to be output to the log.  
Otherwise they are ignored.

=head1 EXPERIMENTAL FEATURES

The following features are experimental, i.e., not yet completely reliable:

=over 4

=item $cfg_restart_interval

This configuration variable causes the s4p_station to restart itself every 
X seconds.  The purpose was to work around a memory leak problem in perl.
However, it can cause perl to coredump, probably due to a flaw in the perl 
binary.

=item $cfg_monitor_performance

This configuration variable causes ps to be run with each polling interval,
showing the memory usage of the s4p_station process. This was to monitor
the memory leak in perl.

=back

=head1 TO DO

ERR: overwrite downstream work order

ERR: no downstream stations specfied

ERR: more than one log file

Correct number of children running

Check config file for suspicious stuff before evaling

Security on STOP, RESTART and RECONFIG

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# s4p_station.pl,v 1.7 2011/11/28 20:53:39 mtheobal Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use Getopt::Std;
require 5.6.0;
use S4P;
use S4P::Station;
use S4P::Job;
use Cwd;
use FindBin qw($Bin);
use strict;
use vars qw($opt_c $opt_d $opt_h $opt_s $opt_t $opt_u $opt_1 $opt_C);
no warnings 'once';

my $start = time();
my @save_args = @ARGV;
my $start_dir = cwd();
getopts('d:c:thu:s1C');
# "Classic" mode...
restart_myself($start_dir, '', \@save_args, "$Bin/stationmaster.pl")
    if ($opt_C);

if ($opt_h) {
    print STDERR "Usage: s4p_station.pl [-d dir] [-c config_file] [-t] [-h] [-1][-C]\n";
    exit 200;
}
if ($opt_d) {
   chdir $opt_d or die "Cannot change to station directory $opt_d";
}

# Check to see if any other s4p_stations are already running here
die ("s4p_station already running here\n") if (S4P::check_station());

my $config_file = $opt_c || 'station.cfg';
my $station = new S4P::Station('config_file'=>$config_file) 
    or die "Could not startup station";

# Read in and evaluate configuration file

# Startup station
$station->startup($opt_u, $opt_t, $opt_1) or die "Failed to startup station\n";

#############################################################
#                  M A I N    L O O P
#############################################################
while (1) {
    # Check our lock file to see if it is still there
    S4P::perish(6, "Lost lock file!") unless (-r "station.lock");
    my @new_files = $station->poll();
    S4P::logger('DEBUG', "New files: " . join(', ',@new_files)) if (@new_files);

    # Check activity monitor if we are running one
    $station->check_activity_monitor;

    # Look for open slots of each datatype if reservations are used
    $station->check_open_slots;

    # Check to see if max_failures has been reached
    $station->check_max_failures;

    # Start processing the new work orders
    foreach my $new_file(@new_files) {
        # Add an extra check for DO.STOP.NOW.wo for the max_children=0 case
        # In this case, we may be spinning off jobs for a long time in this
        # loop before we kick out to glob for STOP work orders
        if ($new_file eq 'DO.VANISH.NOW.wo') {
            my $rc = $station->vanish();
            # If vanish was successful, we will have exited
            # If not, the "nominal case" is still-running jobs, in which case
            # we'll keep polling.
            unless($rc) {
                S4P::Job->new('station'=>$station, 
                    'work_order'=>$new_file)->fail_to_execute();
            }
        }
        elsif ( ($new_file =~ /^DO\.STOP\./) || (-f 'DO.STOP.NOW.wo') ) {
            stop_work($new_file);
        }
        elsif ($new_file =~ /^DO\.RESTART\./) {
            restart_myself($start_dir, $new_file, \@save_args);
        }
        elsif ($new_file =~ /^DO\.RECONFIG\./) {
            unlink($new_file);
            S4P::logger("INFO", "RECONFIG work order detected. Re-reading station.cfg file.");
            $station->configure('config_file' => $config_file);
        } 
        elsif ($station->is_busy) {
            next;
        }
        # Keep this down here instead of outer loop so we can still process 
        # STOP and RESTART work orders
        elsif ($station->max_failures_reached->{'*'}) {
            S4P::logger("DEBUG", "Max number of failed jobs (&{$station->max_failures}) reached, skipping remaining new jobs for now...");
            next;
        }
        else {
            my $job = new S4P::Job('station' => $station, 'work_order' => $new_file);
            if ($job->max_failures_reached) {
                S4P::logger("DEBUG", "Max number of failed jobs reached for " . $job->type);
                $opt_1 ? exit(1) : next;
            }
            S4P::logger("DEBUG", "Processing job $new_file, job_type=" . $job->type);
            $job->run();
        }
        if ($opt_1) {
            S4P::logger("INFO", "Brought up just to run one job. Shutting down this station. Good-bye.");
            exit 0;
        }
    }
    $station->log_performance();
    my $control_file = $station->watchful_sleep();
    # Clean up STOP and RESTART work orders
    # No need to clean VANISH, because the whole station will be gone.
    if ($control_file) {
        if ($control_file =~ /^DO\.STOP\./) {
            stop_work($control_file);
        }
        elsif ($control_file =~ /^DO.RESTART\./) {
            restart_myself($start_dir, $control_file, \@save_args);
        }
    }
}

##########################################################################
# restart_myself($starting_dir, @arguments)
##########################################################################
sub restart_myself {
    my ($dir, $restart_file, $ra_args, $executable) = @_;
    my $uid = (stat $restart_file)[4];
    my $user = (getpwuid $uid)[0];
    $executable ||= $0;  # Default is however we started the first time
    my @args = @$ra_args;
    unlink ($restart_file) if ($restart_file && (-f $restart_file));
    S4P::logger("INFO", join ' ', "Restart issued by $user for $executable", @args);
    if (! chdir $dir) {
        S4P::logger("WARN", "Cannot change back to starting directory $dir");
    }
    elsif (!exec $^X, $executable, @args) {
        S4P::logger("WARN", "Restart of $^X $executable failed: $!");
    }
}
sub stop_work {
    my $file = shift;
    my $uid = (stat $file)[4];
    my $user = (getpwuid $uid)[0];
    S4P::logger('ERROR', "Cannot unlink STOP work order $file: $!") unless (unlink($file));
    S4P::logger("INFO", "STOP work order $file issued by $user detected. Shutting down this station and unlinking $file. Good-bye.");
    exit 101;
}
