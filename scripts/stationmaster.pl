#!/usr/bin/perl -w

=head1 NAME

stationmaster - runs a station within the S4P

=head1 SYNOPSIS

stationmaster.pl  
[B<-d> I<directory>] 
[B<-c> I<config_file>] 
[B<-t>] 
[B<-h>] 
[B<-u> I<umask>]
[B<-s>]
[B<-1>]

=head1 ARGUMENTS

=over 4

=item B<-d> I<directory>

Directory for stationmaster to monitor.  The default is the current directory,
but it is usually helpful to specify this on the command line so that different
instances can be distinguished with the I<ps> command.

=item B<-c> I<config_file>

Configuration file to be loaded. Default is I<station.cfg>, the recommended
filename so that companion programs (e.g. tkstations.pl) can interoperate
with stationmaster.

=item B<-t>

"Tee" the logging to standard error in addition to the station.log file.

=item B<-h>

Print a usage message and exit.

=item B<-u> I<umask>

Umask for stationmaster to run with.  Default is 002 (group-writable).
Example:  I<stationmaster -u 022> will set it the umask to 022. Note the
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

The number of seconds between polls of the child stationmaster
look for the signal files END_JOB_NOW, SUSPEND_JOB_NOW and RESUME_JOB_NOW.  
Default is undefined unless $cfg_group is set, 
in which case this will be the same as $cfg_stop_interval.
(If it is undefined, stationmaster will not look for these files at all.)

=item $cfg_deadline = n seconds

The number of seconds beyond which stationmaster will end the process 
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
Note that since this package is different from stationmaster.pl, the
arguments $a and $b should either be prefaced by "$CFG::" (see Perl
documentation), or better yet, prototyped, e.g.:
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

Username under which stationmaster should be started up.
Stationmaster will fail if user starting it up does not match this user.
This is not for security purposes, just to prevent permission confusion.

=item $cfg_host

Host on which stationmaster should be started up. Stationmaster will fail
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

Tells stationmaster to ignore cases where duplicate work orders have apparently
been sent to a station.  This can appear to happen when file system response
times exceed the polling interval.

=item $cfg_ignore_empty_files

Tells stationmaster to ignore cases where the work order file is empty.
This can happen when file system response times are slow, causing the inode
to appear before the contents.
I<N.B.:  some work orders really ARE zero-length, so use this carefully.>

=item $cfg_restart_defunct_jobs

If set, this will check for defunct jobs on startup:  cases where the job
is dead, but the directory name and job_status still indicate RUNNING.

=item $cfg_rename_retries, $cfg_rename_retry_interval

Parameters that allow stationmaster to make another try at renaming
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

will cause stationmaster to:

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

=head1 ALGORITHM

Read configuration file
DO
   FOREACH file with pattern NEW.*
      IF file = NEW..RECONFIGURE
         Read configuration file
      ELSIF current_number_of_instances < max_instances (configurable)
         Fork off process
         IF Parent
            Set wait handler for child signals
         ELSIF child
            Increment number_of_instances
            Create job directory as RUNNING.*
            Append work order to chain log
            Move work order file to job directory
            Cd to job directory
            Run station script for work order type (configurable)
            Append job log to chain log
            Cd to parent
            IF Failed
               Rename work order file to FAILED.*
               IF error station exists
                  Move output work orders / chain log to error stations
            ELSE
               IF downstream stations exist
                  Move output work orders / chain log to downstream stations
               ELSE
                  Archive chain log
               ENDIF
               Remove job directory
            ENDIF
            Exit
         ENDIF
      ENDIF
   ENDFOREACH
   Sleep (configurable)
ENDDO
WAIT HANDLER:  harvest child

=head1 EXPERIMENTAL FEATURES

The following features are experimental, i.e., not yet completely reliable:

=over 4

=item $cfg_restart_interval

This configuration variable causes the stationmaster to restart itself every 
X seconds.  The purpose was to work around a memory leak problem in perl.
However, it can cause perl to coredump, probably due to a flaw in the perl 
binary.

=item $cfg_monitor_performance

This configuration variable causes ps to be run with each polling interval,
showing the memory usage of the stationmaster process. This was to monitor
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
# stationmaster.pl,v 1.26 2008/11/18 20:54:16 clynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use Getopt::Std;
require 5.6.0;
use Sys::Hostname;
use File::Copy;
use S4P;
use POSIX ":sys_wait_h";
use Cwd;
use constant WALK_IN => '_w';
use strict;
use vars qw($opt_c $opt_d $opt_h $opt_s $opt_t $opt_u $opt_1);
use vars qw(%job_type_order $cmd_has_regex);
no warnings 'once';

my ($cmd, $pkg, $function);     # Used for commands called from Perl packages
my @cmd_args;

my $start = time();
my @save_args = @ARGV;
my $start_dir = cwd();
# Note: -C is a dummy argument, for compatibility with s4p_start.pl
&getopts('d:c:thu:s1C');

if ($opt_h) {
    print STDERR "Usage: stationmaster.pl [-d dir] [-c config_file] [-t][-h]\n";
    exit 200;
}
if ($opt_d) {
   chdir $opt_d or die "Cannot change to station directory $opt_d";
}

# Check to see if any other stationmasters are already running here
die ("stationmaster already running here\n") if (S4P::check_station());

# Lock the station to prevent duplicate stationmasters
lock_station();

# Read in and evaluate configuration file
my $config_file = $opt_c || 'station.cfg';
S4P::read_safe_config($config_file, 'CFG') or 
    die "Could not read config file $config_file\n";
merge_config();

# Set umask to value of -u, or cfg_umask or group writable otherwise in orde.
my $umask = (defined $opt_u)
    ? oct($opt_u) : (defined $CFG::cfg_umask ? $CFG::cfg_umask : 002 );
umask($umask);

# Redirect log file if called for
S4P::redirect_log($CFG::cfg_logfile) if ($CFG::cfg_logfile ne '-' && ! $opt_t);

merge_config();

# Check configuration to see if we can start the station up
prestart_check($CFG::cfg_disable, $CFG::cfg_user, $CFG::cfg_host, \%CFG::cfg_commands);

log_performance() if ($CFG::cfg_monitor_performance);

# Open counter file
S4P::open_counter($CFG::cfg_counter_logfile) or exit 105;

S4P::logger("INFO", "Starting up stationmaster with config file $config_file on host " . hostname());

# Include Perl packages as required by commands
require_command_packages(values %CFG::cfg_commands);

# Check to see if any of the command keys have regular expression characters
my $cmd_has_regex = grep /[\.\*\^\$]/, (keys %CFG::cfg_commands);

$| = 1;

add_station_to_perllib();

# Put together work order patterns that will be globbed
my $input_work_order_pattern = $CFG::cfg_work_order_pattern || 
                               S4P::work_order_pattern($S4P::work_order_prefix, 
                                   $CFG::cfg_input_work_order_suffix);
my $priority_work_order_pattern = 'PRI?.' . $input_work_order_pattern;
S4P::logger("DEBUG", "Looking for files like $input_work_order_pattern");

# Specify sorting function
my $rf_sort_function = setup_sort_function($CFG::cfg_sort_jobs);

my (@new_files, @running_jobs, @failed_jobs, $n_children, $n_failures);
my (%open_slots);

# Run in non-forking mode if we are just doing one job and out
$CFG::cfg_max_children = 0 if $opt_1;

# Setup an activity monitor if $CFG::cfg_max_interval is set
my $activity_monitor = new S4P::ActivityMonitor(
    'max_interval' => $CFG::cfg_max_interval) if ($CFG::cfg_max_interval);

# Restart defunct jobs on startup if configured to do so
S4P::restart_defunct_jobs() if ($CFG::cfg_restart_defunct_jobs);
#############################################################
#                  M A I N    L O O P
#############################################################
while (1) {
    # Check our lock file to see if it is still there
    S4P::perish(6, "Lost lock file!") unless (-r "station.lock");

    @new_files = ();

    # Add STOP, RESTART, and RECONFIG so that they're recognized even 
    # with the standard .wo file name extension
    push @new_files, glob("DO.STOP.*wo");
    push @new_files, glob("DO.RESTART.*wo");
    push @new_files, glob("DO.RECONFIG.*wo");

    # Then look for Priority jobs; note explicit sort function to avoid
    # interpretation of glob as the sort function indicator
    my @priority_files = glob($priority_work_order_pattern);
    my @sort_pri_files = sort alphabetical @priority_files;
    push @new_files, @sort_pri_files;

    # Look for currently running jobs
    @running_jobs = glob('RUNNING.*');

    # Get regular jobs; ignore directories
    my @regular_jobs = grep {-f $_} glob($input_work_order_pattern);
    
    my %max_failures_reached;
    # Look for failed jobs
    if ($CFG::cfg_max_failures || $CFG::cfg_virtual_feedback || %CFG::cfg_auto_restart) {
        @failed_jobs = grep !/^FAILED.WORK_ORDERS/, <FAILED.*>;
        %max_failures_reached = check_max_failures($CFG::cfg_max_failures, @failed_jobs);
    }

    # Requeue failed jobs if cfg_auto_restart_interval is set
    my @restart = restart_failed_jobs(\%CFG::cfg_auto_restart, @failed_jobs) 
        if (%CFG::cfg_auto_restart);
    push (@regular_jobs, @restart) if (scalar(@restart));

    # Add any virtual ("self-seeding") jobs
    virtual_jobs(\@regular_jobs, \@running_jobs, \@failed_jobs, 
        $CFG::cfg_virtual_feedback, \%CFG::cfg_virtual_jobs)
        if (%CFG::cfg_virtual_jobs);

    # Then get the regular jobs and sort if a sort function is specified
    push @new_files, sort $rf_sort_function @regular_jobs;

    # Check activity monitor if we are running one
    $activity_monitor->check(@new_files) if ($activity_monitor);

    # $cfg_max_children=0 (non-forking mode) is designed for stations with high-volume,
    # short-duration jobs.  It runs everything in its queue before looking for more,
    # so it should not need to check the running jobs each polling interval.
    # Also, this kind of station can build up a large queue, so polling can be expensive.
    if ($CFG::cfg_max_children) {
        $n_children = scalar(@running_jobs);
    }
    %open_slots = open_slots(\%CFG::cfg_reservations, \@running_jobs, $CFG::cfg_max_children) if %CFG::cfg_reservations;
    # Start processing the new work orders
    foreach my $new_file(@new_files) {
        # Add an extra check for DO.STOP.NOW.wo for the max_children=0 case
        # In this case, we may be spinning off jobs for a long time in this
        # loop before we kick out to glob for STOP work orders
        if ($new_file =~ /^DO\.STOP\./ || -f 'DO.STOP.NOW.wo') {
            stop_work($new_file);
        }
        elsif ($new_file =~ /^DO\.RESTART\./) {
            restart_myself($start_dir, $new_file, \@save_args);
        }
        elsif ($new_file =~ /^DO\.RECONFIG\./) {
            unlink($new_file);
            S4P::logger("INFO", "RECONFIG work order detected. Re-reading station.cfg file.");

            read_safe_config($config_file, 'CFG') or exit 102;
            merge_config();
        } 
        elsif ($CFG::cfg_max_children && $n_children >= $CFG::cfg_max_children) {
            S4P::logger("DEBUG", "Max number of running children ($CFG::cfg_max_children) reached, skipping remaining new jobs for now...");
            next;
        }
        # Keep this down here instead of outer loop so we can still process 
        # STOP and RESTART work orders
        elsif ($max_failures_reached{'*'}) {
            S4P::logger("DEBUG", "Max number of failed jobs ($CFG::cfg_max_failures) reached, skipping remaining new jobs for now...");
            next;
        }
        elsif ($CFG::cfg_ignore_empty_files && -z $new_file) {
            # Unexpected zero-length work orders can indicate a sick filesystem
            S4P::raise_anomaly('SLOW_FS', '.', 'WARN', 
                "Unexpected zero-length work order $new_file", 0);
            next;
        }
        else {
            my ($job_type, $job_type_and_id, $priority, $rerun) = 
                S4P::parse_job_type($new_file, $CFG::cfg_work_order_pattern);
            if ($max_failures_reached{$job_type}) {
                S4P::logger("DEBUG", "Max number of failed jobs ($CFG::cfg_max_failures->{$job_type}) reached for $job_type");
                $opt_1 ? exit(1) : next;
            }
            S4P::logger("DEBUG", "Processing job $new_file, job_type=$job_type");
            # Check to see if we are reserving slots
            if (%CFG::cfg_reservations) {
                run_reserved_job(\%open_slots, $job_type, $new_file);
            }
            # No reservations:  just run job
            else {
                run_job($new_file);
            }
        }
        if ($opt_1) {
            S4P::logger("INFO", "Brought up just to run one job. Shutting down this station. Good-bye.");
            exit 0;
        }
    }
    log_performance() if ($CFG::cfg_monitor_performance);
    watchful_sleep($CFG::cfg_polling_interval, $CFG::cfg_stop_interval, $start_dir, \@save_args);
    if ($CFG::cfg_restart_interval && ((time() - $start) > $CFG::cfg_restart_interval)) {
        restart_myself($start_dir, '', \@save_args);
    }
}
#########################################################################
# S U B R O U T I N E S
#========================================================================
# prestart_check:  check config to see if station is runnable
#    Checks $cfg_disable
#    Compares $username with $cfg_user
#    Compares $hostname with $cfg_host
#    Checks for command hash
#------------------------------------------------------------------------
# Check to see if I am the right user to start up this station
sub prestart_check {
    my ($disable, $valid_user, $valid_host, $rh_commands) = @_;
    # Check to see if this station is marked as disabled. If so, exit quietly.
    if ($disable) {
        S4P::logger("WARN", 'This station is currently disabled with $cfg_disable. To enable, set $cfg_disable to zero or remove it altogether. Exiting...');
        exit 0;
    }
    my $username = ($^O =~ /Win32/) ? $ENV{'USERNAME'} : getpwuid($<);

    # Check to see if I am the right user to start up this station
    S4P::perish (3, "Only user $valid_user can start this station (see station.cfg)") 
        if ($valid_user && $valid_user ne $username);

    # Check to see if I am on the right machine to start up this station
    if ($valid_host && $valid_host ne hostname()) {
        S4P::perish(4, "You must be on $valid_host to start this station (see station.cfg)");
    }

    # Check to see if there are any commands specified
    S4P::perish(5, "No commands specified, exiting...") if (! %$rh_commands);
    return 1;
}

#========================================================================
# lock_station: open a station.lock file to prevent duplicate stationmasters
# Also writes the PID to the station.pid file.
#------------------------------------------------------------------------
sub lock_station {
    # Open lock file to prevent other stationmasters from running here
    my $lockfile = "station.lock";
    open(FH, "+> $lockfile") or die "Cannot open $lockfile: $!";
    flock(FH, 2 | 4) or die "Cannot write-lock $lockfile: $!";
    my $pid_str = "pid=$$\n"; # Write PID just for debugging
    my $written = syswrite(FH, $pid_str, length($pid_str));
    die "syswrite failed: $!\n" unless $written == length($pid_str);

    # Write to PID file (used for starting/stopping)
    open(PID, ">station.pid") or die "Cannot write to station.pid: $!";
    print PID $pid_str;
    close PID;
}
#========================================================================
# add_station_to_perllib: 
# Account for the fact the script will actually be run in a subdirectory, but
# may be expecting local files (like station-specific config files)
# Add to the environment for system calls
#------------------------------------------------------------------------
sub add_station_to_perllib {
    my $path_sep = ($^O =~ /Win32/i) ? ';' : ':';
    substr($ENV{'PATH'}, 0, 0) = "..$path_sep";
    if ($ENV{'PERL5LIB'}) {
        substr($ENV{'PERL5LIB'}, 0, 0) = "..$path_sep";
    }
    else {
        substr($ENV{'PERLLIB'}, 0, 0) = "..$path_sep";
    }
    # Add to @INC for Perl module calls (so it can find config files)
    unshift @INC, '..';
}
#========================================================================
# require_command_packages(%commands)
#     Check commands and include Perl packages as required
#------------------------------------------------------------------------
sub require_command_packages {
    my @commands = @_;
    foreach my $cmd(grep /::/, @commands) {
        my @cmd_args = (split ' ', $cmd);
        my ($pkg, $function) = split /::/, $cmd_args[0];
        if (! require "$pkg.pm") {
            S4P::logger("FATAL", "Failed to include Perl package $pkg");
            exit 100;
        }
    }
}
#========================================================================
# run_reserved_job:
# If there are open slots for this job type, or there are WALK_IN slots,
# call run_job to run the job.  Otherwise log and return.
#------------------------------------------------------------------------
sub run_reserved_job {
    my ($rh_open_slots, $job_type, $new_file) = @_;
    no warnings 'uninitialized';
    # First try a slot for this job type, then a WALK_IN
    if ($rh_open_slots->{$job_type} > 0) {
        $rh_open_slots->{$job_type}--;
        S4P::logger("DEBUG", "Using $job_type slot to run $new_file, $rh_open_slots->{$job_type} slots left...");
        return run_job($new_file);
    }
    elsif ($open_slots{WALK_IN} > 0) {
        $open_slots{WALK_IN}--;
        S4P::logger("DEBUG", "Using WALK_IN slot to run $new_file, $rh_open_slots->{WALK_IN} slots left...");
        return run_job($new_file);
    }
    else {
        S4P::logger("DEBUG", "Neither job_type nor walk_in slot available for $new_file, skipping to next job...");
        return 0;
    }
}
#########################################################################
# run_job($work_order_file) - runs a job in response to an input workorder
#########################################################################
sub run_job {
    my ($file) = @_;
    my %commands = %CFG::cfg_commands;
    my $use_fork = $CFG::cfg_max_children;
    my $token;
    my $pid;
    # Determine the job_id and the job_type
    my ($job_type, $job_id, $priority, $rerun) = 
        S4P::parse_job_type($file, $CFG::cfg_work_order_pattern);
    # initialize priority to blank string for concatenation purposes
    $priority = '' unless defined($priority); 
    $ENV{'JOB_ID'}=$job_id;

    my $command;
    # Check to see if there is a command for this job type
    if (! ($command=find_job_type($job_type, %commands))) {
        S4P::raise_anomaly('BAD_CONFIG', '.', "FATAL", 
            "Cannot find command for job type $job_type in config file; expecting "
            . join(' or ', sort keys %commands), 2);
        rename_work_order ($file);
        return -1;
    }
    S4P::logger ("INFO", "running job $job_id with command $command and work order $file\n");
#   START counter commented out as it does not appear to be useful
#   S4P::counter("START $job_type");
    FORK: {
        if ($use_fork && ($pid = fork())) {
            # Parent here
            # child process is $pid
            $n_children++;
            S4P::logger ("INFO", "$n_children children running...\n");
            # Wait for the first child to fork (shouldn't take long)
            waitpid($pid, 0);
        }
        elsif (!$use_fork || defined $pid) {
            # Child 1 here or no-fork
            # Now do a second fork for the real work, allowing the parent to
            # get on with its life.
            FORK2: {
                # set $pid2 to $$ in the non-forking case to make later logic simpler
                my $pid2 = $$ unless $use_fork;
                if ($use_fork && ($pid2 = fork()) ) {
                    # Child 1 here:  exit immediately so parent can continue on
                    S4P::logger('DEBUG', "First child exiting");
                    exit(0);
                }
                elsif (defined $pid2) {
                    if ($use_fork) {
                        # Lock may be retained by child/grandchild:  give it up
                        close FH;

                        # Grandchild here:  wait for child 1 to exit
                        sleep($CFG::cfg_child_sleep) if ($CFG::cfg_child_sleep);
                    }

                    # Make job directory
                    my ($newdir, $newfile, $logfile) = make_job_dir($file, $job_id, $priority, $rerun);
                    if (! $newdir) {
                        $use_fork ? exit(106) : return(0);
                    }
                    # Not an error, but no job to process (e.g., ignore_duplicates)
                    elsif (! $newfile) {
                        $use_fork ? exit(0) : return(1);
                    }

                    # Append work order on to end of logfile
                    log_work_order($newfile, $logfile);
                    S4P::logger("INFO", "Running child with work order $file");

                    # Formulate command line
                    @cmd_args = (split ' ', $command);
                    push @cmd_args, $newfile;

                    # Write job.status file
                    S4P::write_job_status('', 'RUNNING', $file, join(' ',@cmd_args));
                    # Check for run token if necessary
                    my %tokens = %CFG::cfg_token;
                    if ($tokens{$job_type}) {
                        S4P::logger('DEBUG', "Obtaining a token for job type $job_type");
                        my $wait = 3600;
                        my $interval = 5;
                        $token =  S4P::request_token($tokens{$job_type}, 
                            getcwd(), $job_id, $wait, $interval);
                        if (! $token){
                            S4P::fail_job($job_id, "Failed to get run token from $tokens{$job_type} after $wait secs", 
                                1, $CFG::cfg_case_log, $CFG::cfg_rename_retries, $CFG::cfg_rename_retry_interval);
                            return 0;
                        }
                    }
                    # If the command is a Perl package routine
                    # Not sure if this still works...
                    if ($cmd_args[0] =~ /::/) {
                        my $r_function = shift @cmd_args;

                        # N.B.: convention for failure (0) is opposite from 
                        # system call
                        my $start_time = time() if $opt_s;
                        my $rc;
                        if ($rc = &$r_function(@cmd_args)) {
                            stop_stats($start_time) if $opt_s;
                            finish_job($job_id, $logfile, $newfile, $file, 
                               $newdir, \%CFG::cfg_downstream, $priority, $token);
                        }
                        else {
                            S4P::update_job_status('.', "FAILED $rc");
                            S4P::fail_job($job_id, "Job (perl module call) failed", 1, 
                                $CFG::cfg_case_log, $CFG::cfg_rename_retries, $CFG::cfg_rename_retry_interval, $token);
                        }
                    }  # Endif Perl Package
                    # Otherwise execute a system command
                    else {
                        my ($ret_string, $exit_code) = execute_command($job_type, 
                            $logfile, @cmd_args);
                        # If successful, finish job (cleanup, move downstream)
                        if (! $ret_string) {
                            finish_job($job_id, $logfile, $newfile, $file, 
                                $newdir, \%CFG::cfg_downstream, $priority, $token);
                        }
                        # If unsuccessful, move directory to FAILED.<stuff>
                        else {
                            S4P::update_job_status('.', "FAILED $ret_string");
                            S4P::fail_job($job_id, $ret_string, $exit_code, $CFG::cfg_case_log, 
                                $CFG::cfg_rename_retries, $CFG::cfg_rename_retry_interval, $token);
                        }
                        # Exit if forking and in child; return if serial
                        if ($use_fork) {
                            exit ($ret_string ? 99 : 0);
                        }
                        else {
                            return($ret_string ? 0 : 1);
                        }
                    } # Endif system command
                } # Endif grandchild
            } # End of FORK2
        } # Endif child 1
        elsif ($! =~ /No more process/) {
            # EAGAIN, supposedly recoverable fork error
            sleep 5;
            redo FORK;
        }
        else {
            # Weird fork error
            die "can't fork: $!\n";
        }
    }
}
sub execute_command {
    my ($job_type, $logfile, @cmd_args) = @_;
    # Win32 likes separate arguments better
    my $start_time = time() if $opt_s;
    my ($ret_string, $exit_code);
    if ($S4P::is_win32) {
        ($ret_string, $exit_code) = S4P::exec_system(@cmd_args);
    }
    # Unix shell likes args together for capture of 
    # stderr & stdout
    else {
        my $cmd = join(' ', @cmd_args) . " >> $logfile 2>&1";
        if ($CFG::cfg_end_job_interval) {
            my $deadline = (ref $CFG::cfg_job_deadline)
                ? $CFG::cfg_job_deadline->{$job_type} 
                : $CFG::cfg_job_deadline;
            S4P::logger('DEBUG', "running nervous_system with interval of $CFG::cfg_end_job_interval and deadline $deadline");
            ($ret_string, $exit_code) = S4P::nervous_system($CFG::cfg_end_job_interval, $deadline, $cmd);
        }
        else {
            ($ret_string, $exit_code) = S4P::exec_system($cmd);
        }
    }
    stop_stats($start_time) if (($opt_s) && (!$ret_string));
    return ($ret_string, $exit_code);
}
sub make_job_dir {
    my ($file, $job_id, $priority, $rerun) = @_;
    # Create a directory for job and chdir there
    my $newdir = "RUNNING.$priority$job_id";
    # If $rerun, reuse the old directory
    # N.B.:  this feature is little-used and little-tested!

    # Check to see if directory already exists
    if (! $rerun && -d $newdir) {
        S4P::raise_anomaly('SLOW_FS', '.', "ERROR", 
            "directory $newdir already exists", 0);
        if ($CFG::cfg_ignore_duplicates) {
            return($newdir);
        }
        else {
            rename_work_order($file);
            return;
        }
    }
    # Create directory for job to run in
    # If $rerun, reuse the old directory
    if (! $rerun && ! mkdir($newdir, 0775)) {
        S4P::logger("FATAL", "Cannot mkdir $newdir: $!");
        rename_work_order($file);
        # Exit if forking; return if serial
        return;
    }
    # Change into new job directory
    # Move work order and log file to new job directory
    my $newfile = "DO.$job_id";
    if (! rename($file, "$newdir/$newfile")) {
        S4P::logger("FATAL", "directory $newdir already exists");
        rename_work_order($file);
        # Exit if forking; return if serial
        return;
    }
    my $logfile = "$job_id.log";
    $ENV{'LOGFILE'} = $logfile;
    if (-e $logfile) {
        rename $logfile, "$newdir/$logfile";
    }
    # Change into new job directory
    chdir $newdir;
    return ($newdir, $newfile, $logfile);
}
#############################################################################
# find_job_type($job_type, %commands):  find the job type in the
#   commands hash and return the command to be executed.  
#   hash lookup if there is no regular expression; if there is a regular
#   expression we need to go through the hash one by one looking for a match.
#############################################################################
sub find_job_type {
    my ($job_type, %commands) = @_;
    # Go directly to value if no regex in command keys
    return $commands{$job_type} if (! $cmd_has_regex);

    # Return exact matches first, for mixed regex/non-regex
    return $commands{$job_type} if (exists $commands{$job_type});

    # Now process the regex command keys
    my ($pattern, $command);
    while (($pattern, $command) = each %commands) {
        return $command if ($job_type =~ /$pattern/);
    }
    # If we got here, we didn't find it
    return 0;
}
##########################################################################
# merge_config():  merge defaults with configuration-file set parameters
##########################################################################
sub merge_config {
    use File::Basename;
    $CFG::cfg_polling_interval ||= 10;
    $CFG::cfg_stop_interval ||= $CFG::cfg_polling_interval;

    # Make sure stop_interval is not greater than polling interval
    $CFG::cfg_stop_interval = $CFG::cfg_polling_interval 
        if $CFG::cfg_stop_interval > $CFG::cfg_polling_interval;;

    if ($CFG::cfg_group) {
        $CFG::cfg_end_job_interval ||= $CFG::cfg_stop_interval;
        $ENV{'S4P_GROUP'} = $CFG::cfg_group;
    }
    else {
        undef $ENV{'S4P_GROUP'} if $ENV{'S4P_GROUP'};
    }

    $CFG::cfg_max_children = 5 unless defined($CFG::cfg_max_children);
    $CFG::cfg_station_name ||= basename(cwd);
    $CFG::cfg_failed_work_order_dir ||= "FAILED.WORK_ORDERS";

    # This is the station's logfile, not the logfiles for individual jobs
    $CFG::cfg_logfile ||= "station.log";
    $CFG::cfg_counter_logfile ||= "station_counter.log";
    $CFG::cfg_input_work_order_suffix ||= $S4P::work_order_suffix;
    $CFG::cfg_output_work_order_suffix ||= $S4P::work_order_suffix;
    $CFG::cfg_child_sleep = 0 unless (defined $CFG::cfg_child_sleep);
   
    $CFG::cfg_rename_retries = 0 unless (defined $CFG::cfg_rename_retries);
    $CFG::cfg_rename_retry_interval ||= 5;
    S4P::logger('DEBUG', "Multi-user mode in group $CFG::cfg_group") if $CFG::cfg_group;
    if ($ENV{OUTPUT_DEBUG}) {
        no strict 'refs';
        my $var;
        foreach $var (sort qw(cfg_polling_interval cfg_max_children
                              cfg_station_name cfg_failed_work_order_dir
                              cfg_logfile cfg_counter_logfile
                              cfg_input_work_order_suffix 
                              cfg_output_work_order_suffix
                              cfg_rename_retries cfg_rename_retry_interval
                              cfg_stop_interval cfg_end_job_interval cfg_deadline
                              cfg_monitor_performance cfg_max_interval)) {
            my $cfg_var = 'CFG::' . $var;
            my $cfg_val = defined($$cfg_var) ? $$cfg_var : 'undef';
            S4P::logger("DEBUG", "$var = $cfg_val");
        }
    }
}
###########################################################################
# finish_job($job_id, $logfile, $newfile, $file, $newdir, \@downstream, 
#     $priority, $token):
# ------------------------------------------------------------------------
#   After work order is completed, send output workorders downstream and
#   cleanup directory, removing input work order and then the job directory
###########################################################################
sub finish_job {
    my ($job_id, $logfile, $newfile, $file, $newdir, $r_downstream, 
        $priority, $token) = @_;
    my %downstream = %{$r_downstream};

    # N.B.:  We are reversing the return code convention here because the
    # child process is going to exit with this return code shortly after this
    # function returns.

    my $rc = 0;
    S4P::logger("INFO", "done with work order $file");
    # Cleanup S4P-specific files
    unlink('job.status');
    unlink('job.message') if (-e 'job.message');
    if (! S4P::send_downstream($logfile, \%CFG::cfg_downstream, $priority, $CFG::cfg_root,
                          $CFG::cfg_output_work_order_suffix)) {
       S4P::logger("FATAL", "cannot move output work order(s)");
       $rc = 2;
    }
    elsif (! unlink $newfile) {
       S4P::logger("FATAL", "cannot delete work order");
       $rc = 1;
    }
    else {
        my @remaining_files = grep !/$logfile/, <*>;
        if (scalar(@remaining_files) > 0) {
            S4P::logger("FATAL", 
                "leftover non-log files:  Cannot remove directory $newdir");
            foreach my $leftover(@remaining_files) {
                S4P::logger("ERROR", "Leftover file: $leftover");
            }
            $rc = 3;
        }
        elsif (-e $logfile && ! unlink($logfile)) {
            S4P::logger("FATAL", "Cannot remove logfile");
            $rc = 4;
        }
        elsif (! (chdir '..' && rmdir $newdir )) {
            S4P::logger("FATAL", "Cannot remove work order subdirectory $newdir: $!");
            $rc = 5;
        }
    }
    if ($rc) {
        my $newname = "FAILED.$job_id." . abs($$);
        S4P::logger("INFO", "Renaming RUNNING.$job_id to $newname");
        chdir '..' if ($rc < 5);   # Never got that far in the process...
        S4P::rename_job_dir("RUNNING.$job_id", $newname, $CFG::cfg_rename_retries, 
            $CFG::cfg_rename_retry_interval) or
            S4P::logger("FATAL", "Failed to rename RUNNING.$job_id to $newname");
    }
    # Release any token that was being used
    S4P::release_token($token) if $token;

    # job_id here is concatenation of job_type and job_id
    my ($job_type) = split('\.', $job_id);
    S4P::counter(($rc ? 'FAILED' : 'SUCCESSFUL') . " $job_type");
    return $rc;
}
sub restart_failed_jobs {
    my ($rh_restart_cfg, @jobs) = @_;
    my %restart;
    my @requeued;
    my $n_jobs = scalar(@jobs);
    return 0 unless ($n_jobs);
    my $now = time();
    my $station_dir = getcwd();
    S4P::logger('DEBUG', "Attempting to restart $n_jobs failed jobs at $now");
    foreach my $job(@jobs) {
        my ($job_type, $job_type_and_id, $priority, $rerun) = 
                S4P::parse_job_type($job, $CFG::cfg_work_order_pattern);
        push @{$restart{$job_type}}, $job;
        # Skip if no entry in restart config hash
        next unless (exists $rh_restart_cfg->{$job_type});
    }

    # Foreach job_type, restart (gently) if ready
    foreach my $job_type(keys %restart) {
        S4P::logger('DEBUG', "Restarting job_type $job_type");
        my $clock_file = "RESTART_CLOCK.$job_type";

        # Look for a current scout job (running, pending or failed)
        my $scout_signal = "RESTART_SCOUT.$job_type";
        # Look for signal file to restart a scout job
        if (-f $scout_signal) {

            # Read and parse scout signal file
            my $buf = S4P::read_file($scout_signal);
            chomp($buf);
            my ($job_info, $orig_work_order) = split(/\s/, $buf);
            S4P::logger('DEBUG', "Looking for scout job $job_info or work order $orig_work_order");

            # Look to see if the scout job is still in the pending queue
            # If a scout job is pending, take no action
            if (-f $orig_work_order) {
                S4P::logger('DEBUG', "Scout job $orig_work_order is pending");
                next;
            }
            # Next see if the scout is currently running
            # If a scout job is running, take no action
            my ($job_dir) = glob("RUNNING.$job_info.*");
            if ($job_dir && -d $job_dir) {
                S4P::logger('DEBUG', "Scout job $job_dir is still running");
                next;
            }
            # Check to see if scout job is either FAILED or not yet started
            $job_dir = glob("FAILED.$job_info.*");
            # if scout job failed, cleanup and restart timer to send out the
            # next scout
            if ($job_dir && -d $job_dir) {
                S4P::logger('WARN', "Scout job failed ($job_dir), resetting timer");
                S4P::write_file($clock_file, sprintf("%d\n", $now));
                unlink($scout_signal);
            }
            # No sign of scout job, so it must have succeeded
            else {
                unlink($scout_signal);
                S4P::logger('INFO', "Scout job $job_info succeeded, restarting all jobs of type $job_type");
                # Since scout succeeded, restart all the rest of the jobs
                foreach my $job(@{$restart{$job_type}}) {
                    chdir($job);
                    my $restarted = S4P::restart_job();
                    if ($restarted) {
                        push @requeued, $restarted;
                        unless (S4P::remove_job()) {
                            S4P::logger('ERROR', "Failed to remove $job");
                        }
                    }
                    else {
                        S4P::logger('ERROR', "Failed to restart job $job: $!");
                    }
                    chdir($station_dir);
                }
            }
        }
        # Else if there is no scout job signal file
        #   If no timer file, init the timer
        #   Else check timer to see if it is time to send out a scout
        else {
            if (! -f $clock_file) {
                S4P::write_file($clock_file, sprintf("%d\n", $now));
            }
            else {
                my $start = S4P::read_file($clock_file);
                my $interval = $rh_restart_cfg->{$job_type}->{'interval'};
                S4P::logger('DEBUG', "Now=$now Start=$start Interval=$interval");
                # Time's up:  send out a scout job
                if ( ($now - $start) > $interval) {
                    my $scout_job = $restart{$job_type}[0];
                    S4P::logger('INFO', "Restarting scout job $scout_job");
                    chdir($scout_job);
                    my $orig_work_order = S4P::restart_job();
                    if (!$orig_work_order) {
                        S4P::logger('ERROR', "Failed to restart scout job $scout_job");
                    }
                    elsif (!S4P::remove_job()) {
                        S4P::logger('ERROR', "Failed to remove scout job $scout_job");
                    }
                    push @requeued, $orig_work_order;
                    chdir($station_dir);
                    $scout_job =~ s/^FAILED.//;
                    $scout_job =~ s/\.\d+$//;
                    S4P::write_file($scout_signal, "$scout_job $orig_work_order\n");
                }
            }
        }
    }
    return @requeued;
}
##########################################################################
# log_work_order($work_order, $logfile):  save input work order into the
#   mobile log file (the one that trails along in the job chain, not the
#   station log)
##########################################################################
sub log_work_order {
    my($work_order, $logfile) = @_;
    if (! open (LOGFILE, ">>$logfile")) {
        S4P::logger("FATAL", "Cannot open log file $logfile");
        return 0;
    }
    print LOGFILE '=' x 72, "\n";
    printf LOGFILE "%s %-5.5d %s\n", S4P::timestamp(), $$, 
        $CFG::cfg_station_name;
    if (! open WORKORDER, $work_order) {
        S4P::logger("FATAL", "Cannot open work order file $work_order");
        return 0;
    }
    while (<WORKORDER>) { print LOGFILE; }
    close WORKORDER;
    print LOGFILE "-" x 72, "\n";
    close LOGFILE;
    return 1;
}
##########################################################################
# rename_work_order($file):  rename work order that failed to be executed
#   and put it in the FAILED.WORK_ORDERS directory
##########################################################################
sub rename_work_order {
    my $file1 = shift;
    my $file2 = $file1;
    my $fail_dir = $CFG::cfg_failed_work_order_dir;
    my $input_suffix = $CFG::cfg_input_work_order_suffix;
    # See if FAILED.WORK_ORDERS directory exists; mkdir if not
    if (! -d $fail_dir) {
        if (! mkdir $fail_dir, 0775) {
            S4P::logger("FATAL", "Can't mkdir $fail_dir for failed work orders: $!");
            return 0;
        }
    }
    # Insert a process_id before the trailing suffix for uniqueness
    $file2 =~ s#\.$input_suffix#.$$.$input_suffix#;
    if (! rename $file1, "$fail_dir/FAILED.$file2") {
        S4P::logger("FATAL", 
         "Can't rename $file1 to $fail_dir/FAILED.$file2: $!");
        return 0;
    }
    else {
        S4P::logger("INFO", 
        "Renamed failed work order $file1 to $fail_dir/FAILED.$file2");
        return 1;
    }
}
##########################################################################
# log_performance():  log user and system time for parent and child, along
#   with memory.
##########################################################################
sub log_performance {
    my @times = times();
    my @mem = `ps -p $$ -o sz`;
    shift @mem;
    chomp(@mem);
    S4P::logger("INFO", "User=$times[0] Sys=$times[1] ChldUser=$times[2] ChldSys=$times[3] Mem=$mem[0]");
    return 1;
}
##########################################################################
# restart_myself($starting_dir, @arguments)
##########################################################################
sub restart_myself {
    my ($dir, $restart_file, $ra_args) = @_;
    my @args = @$ra_args;
    unlink ($restart_file) if ($restart_file && (-f $restart_file));
    S4P::logger("INFO", join ' ', "Restarting $0", @args);
    if (! chdir $dir) {
        S4P::logger("WARN", "Cannot change back to starting directory $dir");
    }
    elsif (!exec $^X, $0, @args) {
        S4P::logger("WARN", "Restart of $^X $0 failed: $!");
    }
}
#########################################################################
# Job sorting functions
#=========================================================================
sub setup_sort_function {
    my $sort_jobs = shift;
    my $rf_sort_function;
    if (! $sort_jobs) {
        $rf_sort_function = 'alphabetical';
        S4P::logger('DEBUG', "Sorting jobs alphabetically");
    }
    elsif (ref $sort_jobs) {
        $rf_sort_function = 'by_job_type';
        map {$job_type_order{$sort_jobs->[$_]} = $_} 0..scalar(@$sort_jobs);
        S4P::logger('DEBUG', "Sorting by job type");
    }
    elsif ($sort_jobs eq 'FIFO') {
        $rf_sort_function = 'fifo';
        S4P::logger('DEBUG', "Sorting jobs by FIFO");
    }
    elsif ($sort_jobs =~ /::/) {
        # Strip off function to get module for require
        my @module = split('::', $sort_jobs);
        pop @module;
        my $req = join('::', @module);
        eval "require $req" or S4P::perish(2, "Cannot require sort module $req: $!");
        $rf_sort_function = $sort_jobs;
        S4P::logger('DEBUG', "Sorting jobs using custom sort $sort_jobs");
    }
    else {
        S4P::perish(2, "Unrecognized job sort type: $sort_jobs");
    }
    return $rf_sort_function;
}
sub by_job_type {
    my ($prefix, $job_a, $job_b);
    ($prefix, $job_a) = split('\.', $a);
    ($prefix, $job_b) = split('\.', $b);
    return $job_type_order{$job_a} <=> $job_type_order{$job_b};
}
sub fifo {
    # -M gives age of file, so we want the oldest first
    return ( (-M $b) <=> (-M $a) );
}
sub alphabetical {
    return ($a cmp $b);
}
sub open_slots {
    my ($rh_reservations, $ra_running_children, $max_children) = @_;
    my (%running, %open);
    my ($job_type, $job_id, $n_reserved);
    foreach my $job(@$ra_running_children) {
        ($job_type) = S4P::parse_job_type($job, $CFG::cfg_work_order_pattern);
        $job_type = WALK_IN unless ($rh_reservations->{$job_type});
        $running{$job_type}++;
    }
#   open(type) = res(type) - running(type)
#   open(walk_in) = max_children - sum(max(res(type),running(type)) - running(walk_in)
    my $n_walk_in = $max_children - $running{WALK_IN};
    while (($job_type, $n_reserved) = each %$rh_reservations) {
        if ($n_reserved > $running{$job_type}) {
            $open{$job_type} = $n_reserved - $running{$job_type};
            $n_walk_in -= $n_reserved;
        }
        else {
            $open{$job_type} = 0;
            $n_walk_in -= $running{$job_type};
        }
    }
    $open{WALK_IN} = ($n_walk_in > 0) ? $n_walk_in : 0;
    return %open;
}
# Virtual jobs are "self-seeding".
# They do not require a work order.  Instead stationmaster will
# create work orders on its own up to the limit specified.
# Thus, it takes the configuration hash of number of jobs for a given 
# job type, subtracts the number of currently pending or running jobs
# of that job type and creates the resulting number of work orders.
# CAUTION:  Works only with "standard" job names, like DO.*
sub virtual_jobs {
    my ($ra_pending_jobs, $ra_running_jobs, $ra_failed_jobs, $feedback, $rh_virtual_jobs) = @_;
    my (@current, %extant);
    my $i;
    push (@current, @$ra_pending_jobs, @$ra_running_jobs);
    # Add failed jobs if feedback switch is set
    push (@current, @$ra_failed_jobs) if $feedback;
    foreach my $job(@current) {
        my ($job_type) = S4P::parse_job_type($job, $CFG::cfg_work_order_pattern);
        $extant{$job_type}++;
    }
    my $t = time();
    my @jobs;
    # Foreach virtual job type:
    #   See how many virtual jobs we should have
    #   Subtract the number of pending or running jobs of that type
    #   Write a short file of type DO.<job_type>.<time><nnn>.<suffix>
    foreach my $job_type(keys %$rh_virtual_jobs) {
        my $njobs = $rh_virtual_jobs->{$job_type};
        $njobs -= $extant{$job_type} if $extant{$job_type};
        for ($i = 0; $i < $njobs; $i++) {
            my $f = sprintf("DO.%s.%d%03d.%s", $job_type, $t, $i, 
                $CFG::cfg_input_work_order_suffix);
            if (!open F, ">$f") {
                S4P::raise_anomaly('BAD_PERM', '.', 'ERROR', 
                  "Cannot write to virtual work order $f: $!", 2);
                next;
            }
            print F "Virtual Work Order: $f\n";
            close F or 
              S4P::logger('ERROR', "Cannot close virtual work order $f: $!");
            push @jobs, $f;
        }
    }
    push @$ra_pending_jobs, @jobs;
    return @jobs;
}
#########################################################################
# stop_stats - Record and calculate the average execution time.
#   Judd Taylor, USF Institute for Marine Remote Sensing
#   July 16, 2002
#=========================================================================
sub stop_stats {
    my $start = $_[0];
    my $stop = time();
    my @stats = [0,0,0];
    # Open up the station.stats file, or try to create it.
    if ( ! -e "../station.stats" ) {
        S4P::logger("WARN", "File \"../station.stats file\" does not exist,
I will create it.");
    } else {
        if ( ! open(STATIONSTATS, "../station.stats") ) {
                S4P::logger("WARN", "Cannot open \"../station.stats\" file:
$!\n");
                return 1;
        }
        @stats = <STATIONSTATS>;
        close STATIONSTATS;
        chomp @stats;
    }
    # Calculate the new stats
    $stats[2] += ($stop - $start);
    $stats[1]++;
    $stats[0] = $stats[2] / $stats[1];
    # Write out the new stats
    if ( ! open(STATIONSTATS, ">../station.stats") ) {
        S4P::logger("WARN", "Cannot clobber \"station.stats\" file: $!\n");
        return 2;
    }
    print STATIONSTATS join("\n", @stats) . "\n";
    close STATIONSTATS;
    return 0;
} # stop_stats()...
sub stop_work {
    my $file = shift;
    S4P::logger('ERROR', "Cannot unlink STOP work order $file: $!") unless (unlink($file));
    S4P::logger("INFO", "STOP work order detected. Shutting down this station and unlinking $file. Good-bye.");
    exit 101;
}
# Sleep, but keep an eye out for stop or restart work orders
sub watchful_sleep {
    my ($poll, $check, $start_dir, $ra_save_args) = @_;
    # Compute number of integral sub-intervals, plus remainder
    my $n = int($poll / $check);
    my $rem = $poll % $check;
    my $stop_file = 'DO.STOP.NOW.wo';
    my $restart_file = 'DO.RESTART.NOW.wo';
    # Sleep for whole intervals, but check each time for STOP
    # or RESTART work orders
    foreach (1..$n) {
        stop_work($stop_file) if (-f $stop_file);
        restart_myself($start_dir, $restart_file, $ra_save_args) if (-f $restart_file);
        sleep($check);
    }
    return unless $rem;
    stop_work($stop_file) if (-f $stop_file);
    restart_myself($start_dir, $restart_file, $ra_save_args) if (-f $restart_file);
    sleep($rem);
}
sub check_max_failures {
    my ($cfg_max_failures, @failed_jobs) = @_;
    return unless ($cfg_max_failures);
    my %max_failures_reached;
    my $anomaly;
    # $cfg_max_failures is a hash reference (not a regular scalar)
    # Check job-specific max_failures (key to the hash)
    if (ref $cfg_max_failures) {
        # Parse and count failed job types
        my %failed_jobs;
        foreach my $job(@failed_jobs) {
            my ($job_type) = S4P::parse_job_type($job, $CFG::cfg_work_order_pattern);
            $failed_jobs{$job_type}++;
        }
        # For each job_type with a max_failures set, see if it has been reached
        foreach my $job_type(keys %$cfg_max_failures) {
            if ($failed_jobs{$job_type} >= $cfg_max_failures->{$job_type}) {
                $max_failures_reached{$job_type} = $failed_jobs{$job_type};
            }
        }
        $anomaly = "At max failures: " . join(',', keys %max_failures_reached)
            if (%max_failures_reached);
    }
    # Total max_failures case ($cfg_max_failures is a scalar)
    elsif (scalar(@failed_jobs) >= $cfg_max_failures) {
        # Set max_failures_reached hash to magic wildcard key '*'
        $max_failures_reached{'*'} = scalar(@failed_jobs);
        $anomaly = "At or above max failures: N=$max_failures_reached{'*'}";
    }
    # Raise anomaly if above max failures
    if (%max_failures_reached) {
        S4P::raise_anomaly('MAXFAIL', '.', 'WARN', $anomaly, 2);
    }
    # If we are under max_failures, then delete the signal file
    else {
        S4P::clear_anomaly('MAXFAIL', '.');
    }
    return %max_failures_reached;
}
package S4P::ActivityMonitor;
use strict;
1;
sub new { my ($pkg, %params) = @_; bless \%params, $pkg; }
# max_interval:  configuration parameter with max time we should expect
#   to see between work orders
sub max_interval {my $this = shift; @_ ? $this->{'max_interval'} = shift
                                       : $this->{'max_interval'}}
# last_arrival:  epochal time of last real work order
sub last_arrival {my $this = shift; @_ ? $this->{'last_arrival'} = shift
                                       : $this->{'last_arrival'}}
sub check {
    my ($this, @work_orders) = @_;
    my $now = time();
    my $last_arrival = $this->last_arrival();
    # Just started up:  initialize timer and return
    unless ($last_arrival) {
        $this->last_arrival($now);
        return 1;
    }
    my @real_work = grep !/^DO\.(STOP|RECONFIG|RESTART)\./, @work_orders;

    # If we got some real work to do, reset the timer and clear any anomaly
    if (@real_work) {
        $this->last_arrival($now);
        S4P::clear_anomaly('TOO_QUIET', '.');
    }
    # If no work, and it's past time we should have gotten some, then
    # raise the alarm.
    elsif (($now - $last_arrival) > $this->max_interval) { 
        my $diff = $now - $last_arrival;
        my $hr = int($diff/3600);
        my $min = int(($diff % 3600) / 60);
        my $sec = ($diff % 60);
        my $diff_str = sprintf("%02d:%02d:%02d", $hr, $min, $sec);
        S4P::raise_anomaly('TOO_QUIET', '.', 'WARN', 
            "It's quiet out there. Almost too quiet. No work for $diff_str", 1);
        return 0;
    }
    # Non-zero return means nothing to worry about (yet)
    return 1;
}
