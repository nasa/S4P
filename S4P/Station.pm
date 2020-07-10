=head1 NAME

S4P::Station - object to instantiate an S4P station for processing work orders

=head1 SYNOPSIS

=head2 Basic Operations

  use S4P::Station;

  my $station = new S4P::Station('config_file' => 'station.cfg');

  $station->configure($config_file);

  $station->startup();

  @work_orders = $station->poll()

  $restart_file = $station->watchful_sleep();

  $station->check_open_slots();

  $busy = $station->is_busy();

  $station->check_max_failures();

  %maxfail = %{$station->max_failures_reached()};

  $station->check_activity_monitor();

  $station->log_performance();

=head2 Attribute Methods

Attributes are set by passing the value as an argument, e.g.,

  $station->polling_interval(5);

and retrieved by calling the method with no argument, e.g. 

  $polling_interval = $station->polling_interval;

The accessible attributes are:
  activity_monitor
  blackout
  commands
  child_sleep
  downstream
  end_job_interval
  failed_jobs
  failed_work_order_dir
  ignore_duplicates
  ignore_empty_files
  input_work_order_suffix
  job_deadline
  job_list
  log_statistics
  lock_handle
  max_children
  max_failures
  max_failures_reached
  num_running
  open_slots
  output_work_order_suffix
  poll_dir
  polling_interval
  queued_jobs
  reservations
  root
  running_jobs
  sort_jobs
  start_time
  station_name
  stop_interval
  token
  vanishing
  virtual_feedback
  virtual_jobs
  work_order_pattern

=head1 DESCRIPTION

S4P::Station is part of an object-oriented replacement of the old stationmaster.

=over 4

=item new

The station is instantiated with a configuration file, within the 
working directory.

=item configure

The configure method is called by new().  However, it can also be called at
a later time to reconfigure the station.

=item startup

The startup method first sets the umask and then initiates logging.
It also does a prestart check to see if we have the station being started
on the correct host (according to the configuration file) and by the right user.
It then does some setup to make sure that modules and functions can be found.
It then initializes some attributes according to the station configuration
and starts the activity monitor if a max interval between work orders has been
set in the config file.

=item poll

The poll method looks for new work orders, failed jobs, and running jobs.
By default it looks in the current directory, but if the $cfg_poll_dir
variable is set in the config file, it will look there for new work orders,
whereupon it moves them over to the current directory for processing.
The list of new work orders

=item watchful_sleep

The watchful_sleep method "sleeps" until it is time to poll again.
However, it actually takes a series of catnaps ($cfg_end_job_interval long), 
looking for the appearance of STOP work orders until the full polling
period is up and it is time to do a full poll.

=item check_open_slots

The check_open_slots method is used of %cfg_reservations is specified in
the configuration file. It looks at the number of running jobs of each
type to determine how many open job slots are available for each job type.

=item is_busy

The is_busy method returns 1 if the station is running as many children
as it is allowed, and 0 otherwise.

=back

=head2 Autonomic Features

These are features to enable autonomic computing, i.e., self-adjusting, 
self-healing, etc.

=over 4

=item auto_restart

The station can be configured to restart failed jobs on regular intervals.
This is useful for off-hours operations when transient conditions can cause
failures (such as an external interface that is temporarily down).
The restart is a careful one:  first a "scout" job is restarted.  
If that job succeeds, then the other failed jobs of that type are restarted.
If not, the station waits until the next interval before trying a scout job again.

The B<%cfg_auto_restart> configuration variable is a hash of hashes, 
with job_type as the key.  This allows a restriction so that only 
certain jobs are susceptible to auto_restart.
The value is a hash with two elements:
  'interval' (required) - the time interval for retries
  'script' (optional) - a command-line restart script

If 'script' is not specified, the function S4P::restart_job is run.
The restart script should expect no arguments, assume it is in the failed
directory, and do whatever it thinks proper to re-inject the work order 
into the parent station directory.

Example: 
  %cfg_auto_restart = (
      'TEST1' => {'interval' => 10, 'script' => '../my_restart.sh'}
  );

=item blackouts

Periods of time during which the station will quiesce for certain types of jobs.
That is, it will ignore work orders of that type during that period.
The period should be specified as HHMM in GMT (e.g. 2355 = 11:55 PM GMT):
   %cfg_blackouts = (
      'TEST1' => [ [HHMM, HHMM], [HHMM, HHMM], ...]
   );

=item check_activity_monitor

Check to see when the station last received a new work order.
Long time spans between work orders may indicate upstream problems (TOO_QUIET).
This requires setting the $cfg_max_interval in the station.cfg file.
See diagnostics.

=item check_max_failures

The max_failures_reached method returns a reference to a hash of which 
job_types have reached the max_failures limit and therefore will not 
process anymore new orders.

=item ignore_empty_files

The ignore_empty_files is an attribute set/get routine that is used with
overburdened filesystems where work order files can show up (temporarily)
without any contents. 

=item ignore_duplicates

The ignore_duplicates is an attribute set/get routine that is used with
overburdened filesystems where a work order may not have been moved to its
new job directory before the next polling interval comes around.
This is queried by the Job object when setting up the job directory.

=item vanish

This is a station that "vanishes" when a DO.VANISH.NOW.wo work order
is received.  That is to say, it deletes all of its subdirectories and
files, including station.cfg and station.log before quitting (for the last time).
Only stations with the B<vanishing> attribute set (to a non-null value) will vanish.

=back

=head2 Attribute Methods

Not all attributes are accessible via a method.  (Some are used only by other
methods.)

=over 4

=item activity_monitor

Handle for an internal S4P::ActivityMonitor object.

=item commands

Reference to a hash of job_type => command, i.e., what actually gets run
for each job type.

=item child_sleep

(Deprecated).  Artificial sleep time when forking to account for flaky OS.

=item downstream

Reference to a hash with key job_type and value anonymous array of 
downstream stations, i.e., where output work orders get sent.

=item end_job_interval

How many seconds to sleep before looking for a signal file in the job 
directory.  This is queried by the Job object as it runs.
In multi-user mode, if this is not set in the configuration file,
it will be set to the stop_interval (see below).

=item failed_jobs

Reference to the array of failed jobs in the station directory.

=item failed_work_order_dir

Alternatet location for work orders that fail to execute due to
configuration problems.  This is deprecated; there seems to be no use
for it.

=item ignore_duplicates

Whether to ignore apparent duplicate work orders (can happen with a
slow/busy filesystem).  Queried by the Job object.

=item ignore_empty_files

Whether to ignore empty work orders.  For some stations, these are
expected, and so this should not be set.  For others, empty work
orders can appear when the file system is slow/busy (see DIAGNOSTICS).

=item input_work_order_suffix

Alternate suffix for input work order.  Default is 'wo'.

=item job_deadline

Deadline after which a job is automatically killed (applies to multi-user
mode only). This can be a scalar, applying to all jobs in the station,
or a hash reference with deadlines for each job_type.

=item job_list

Reference to an array of unsorted list of new jobs detected in the
last polling interval (used by the activity monitor).

=item log_statistics

Whether to log performance statistics or not.  Default is no (undef).

=item lock_handle

Handle to lock opened up on station.lock file.  Queried by Job object
after forking so it can close the child's copy of the lock.

=item max_children

Maximum number of children that can be running at one time to process jobs.
Default is 5.

=item max_failures

Maximum number of failed jobs before the station stops processing new jobs.
This can be a total (scalar) or different for each job type (hash reference).

=item max_failures_reached

This is a hash reference keyed on job type that shows whether max_failures
has been reached.  For the total case, it uses '*' as the hash key.

=item num_running

The number of jobs currently running.

=item open_slots

A hash reference with the number of open slots for each job_type when 
reservations are in effect.

=item output_work_order_suffix

Alternate suffix to append to output work orders on their way downstream.  
This has special behavior if this variable is set to 'log'.
In this case, the log file is the same as the output work order, and only
the output work order will be moved downstream, to avoid unnecessary
duplication.

Default is 'wo'.

=item poll_dir

Alternate directory to poll for work orders.  Work orders in this directory
are moved to the station directory where they are then processed.

=item polling_interval

Time interval to check for new work orders.  Default is 10 seconds.

=item queued_jobs

Reference to array of jobs in the queue.

=item reservations

Hash reference of reservations by job_type.
The key of the hash is the job type and the value is the number of reserved
job "slots" for that job type:

  %cfg_reservations = ('ALLOCATE_MoPGE01' => 1, 'ALLOCATE_MoPGE02' => 5);

If max_children is greater than the total number of reservations, "walk-ins"
will be accepted for the extra slots.
If some job types do not have reservations, they can ONLY get walk-in slots.

B<N.B.:  Make sure that max_children is greater than or equal to the total
number of reservations.>


=item root

Root of S4P station tree.  This is prepended to the names of the
downstream stations when sending work orders downstream.

=item running_jobs

Reference to array of jobs currently running.

=item sort_jobs

How to sort jobs when prioritizing them.
Below shows the behaviour based on values from the station.cfg file.

=over 4

=item $cfg_sort_jobs = 'FIFO';

Executes the jobs in a first-in-first-out order.

=item $cfg_sort_jobs = ['job_type1', 'job_type2',...];

Executes the jobs as specified in the anonymous array.

=item $cfg_sort_jobs = "MySort::sort_function";

This allows a station-specific sort function to be specified.
Simply put a module in the station directory (e.g. MySort.pm)
with a function to do the sorting the way I<you> want it to work.
The arguments $a and $b should prototyped, e.g.: 
  sub by_strlen($$) {
    my ($a, $b) = @_;
    ...

=back

=item start_time

Epochal time at which station was started.

=item station_name

Name of station (used by graphical monitor, tkstat).

=item stop_interval

Interval used for polling for STOP work orders in the station.
Default is the same as the polling interval, but this should
usually be shorter.

=item token

(Experimental.)  
For a given job_type, lists the directory of the tokenmaster station.
When this is set, the job will be spawned but will not begin executing
until it receives a token from the tokenmaster station.

=item vanishing

Whether the station is susceptible to vanishing, when triggered by a
DO.VANISH.NOW.wo work order.

=item virtual_feedback

For virtual jobs (see below), include failed jobs when counting up current 
jobs for a given type if set to nonzero.

=item virtual_jobs

Sets up "virtual" work orders, aka self-seeding recycling work orders.
It is a hash whose key is JOB_TYPE and value is the number to keep
in the pipeline.  For example, setting:

  %cfg_virtual_jobs = ('FOOBAR' => 2);

in the station.cfg file ( or $station->virtual_jobs({'FOOBAR'=>2}) )
file will cause the poll() method to:

(1) See if the total number of pending and running FOOBAR jobs is less than 2.
If $virtual_feedback is set to non-zero, failed jobs are also included in
the count.

(2) Write short files of type DO.<job_type>.<time><nnn>.<suffix> until there are 2

Note that if you use this, there is no need to have your script create an output
work order for recycling.

=item work_order_pattern

This is a glob pattern (not a regular expression pattern) which can be used
instead of input_work_order_suffix to specify a the whole
work order pattern, overriding the normal DO. prefix.  This is useful for
stations that are detecting "foreign" work orders that don't follow S4P naming
conventions.

=back

=head1 DIAGNOSTICS

Most erorr conditions are to be found by looking in the station.log file.

Certain conditions also cause signal files to be written to the station 
directory.  These have the form ANOMALY.<TYPE>.log.  
They are detected by tkstat and displayed to the user by tkstat, which also
offers an opportunity to clear the anomaly signal file.

=over 4

=item BAD_PERM

Failed to write virtual work orders to the current directory (very rare).
Requires setting $cfg_virtual_jobs.

=item MAXFAIL

Maximum number of failures reached in total or for a specific job type:  no
more work orders of that type will be processed until some failures are
cleared up.  Requires setting $cfg_max_failures.

=item SLOW_FS

Zero-length work order detected; file was there but nothing in it yet.
Requires setting $cfg_ignore_empty_files.

=item NO_VANISH

Got a VANISH work order, but not configured to allow it.

=item TOO_QUIET

It has been too long since we saw our last new work order, usually indicating
a problem upstream.  Requires setting $cfg_max_interval.

=back

=head1 FILES

station.cfg - configuration file for S4P station

=head1 LIMITATIONS

Currently assumes that the current directory is the working directory.

=head1 AUTHOR

Chris Lynnes, NASA/GSFC

=cut

package S4P::Station;
use S4P;
use File::Basename;
use File::Path;
use Cwd;
use Sys::Hostname;
use File::Copy;
use strict;
use constant WALK_IN => '_w';
our $count = 0;
1;
sub new { 
    my ($pkg, %params) = @_; 
    my $station = bless \%params, $pkg;
    
    # Check to see if station is already running
    if (S4P::check_station()) {
        warn ("s4p_station.pl already up here\n");
        return;
    }

    # Lock station
    $station->lock() or return;

    # Read in configuration file
    $station->configure($params{'config_file'}) if $params{'config_file'};

    return $station;
}
sub configure {
    no strict 'refs';
    my ($this, $config_file) = @_;
    # Setup unique namespace
    my $ns = "STA" . $count++;

    # Read configuration file
    if (! S4P::read_safe_config($this->{'config_file'}, $ns) ) {
        warn "Cannot read station config file: $!\n";
        return;
    }
    # Scoop up station stuff

    ############### Basic Configuration
    $this->set_config('poll_dir', $ns);
    # Default station name is current directory
    $this->set_config( 'station_name', $ns, basename(cwd()) );
    $this->set_config('root', $ns, '../..');

    # Disable the station
    $this->set_config('disable', $ns);

    ############# Alternate directories and files
    # Alternate directory for work orders that cannot execute
    $this->set_config('failed_work_order_dir', $ns, "FAILED.WORK_ORDERS");
    # Default logfile = station.log
    $this->set_config('logfile', $ns, 'station.log');
    $this->set_config('counter_logfile', $ns, 'station_counter.log');

    ############# Polling info
    # Default interval is 10 seconds
    $this->set_config('polling_interval', $ns, 10);

    # How often we look for DO.STOP work orders: Default to polling interval
    $this->set_config('stop_interval', $ns, $this->{'polling_interval'});
    # Make sure stop_interval is not greater than polling interval
    $this->{'stop_interval'} = $this->{'polling_interval'}
        if $this->{'stop_interval'} > $this->{'polling_interval'};

    # How often we look for signal file that a job should end
    $this->set_config('end_job_interval', $ns);

    ############# Multi-user mode
    # Multi-user mode if group is set
    $this->set_config('group', $ns);
    if ($this->{'group'}) {
        # Make sure end_job_interval is set to something for multi-user mode
        # It is the only way to terminate jobs
        $this->{'end_job_interval'} ||= $this->{'stop_interval'};
        $ENV{'S4P_GROUP'} = $this->{'group'};
        S4P::logger('DEBUG', "Multi-user mode in group $this->{'group'}");
    }
    else {
        undef $ENV{'S4P_GROUP'} if $ENV{'S4P_GROUP'};
    }

    ############# Configuration for slow filesystems
    $this->set_config('ignore_duplicates', $ns);
    $this->set_config('ignore_empty_files', $ns);

    # Default max_children is 5
    # N.B.:  0 is a valid value - means no forking
    # $cfg_max_children=0 (non-forking mode) is designed for stations with 
    # high-volume, short-duration jobs.  
    # It runs everything in its queue before looking for more,
    # so it should not need to check the running jobs each polling interval.
    $this->set_config('max_children', $ns, 5);

    ############# Autonomic computing
    $this->set_config('case_log', $ns);
    $this->set_config('max_failures', $ns);
    $this->set_config('job_deadline', $ns);
    $this->set_config('max_interval', $ns);
    $this->set_config('monitor_performance', $ns);
    $this->set_config('rename_retries', $ns);
    $this->set_config('rename_retry_interval', $ns, 5);
    $this->set_config('restart_defunct_jobs', $ns);
    $this->set_config('restart_interval', $ns);
    $this->set_config('vanishing', $ns);
    $this->set_config('virtual_feedback', $ns);
    $this->set_config('max_time', $ns);

    ############# Job Sorting
    $this->sort_jobs(${$ns . '::cfg_sort_jobs'});

    # Default umask is 002
    $this->set_config('umask', $ns, 002);

    ############# Checks on whether we have the right host/user
    $this->set_config('host', $ns);
    $this->set_config('user', $ns);

    ############# Alternative work order patterns
    # Work order suffix / pattern
    $this->set_config('input_work_order_suffix', $ns, $S4P::work_order_suffix);
    $this->set_config('output_work_order_suffix', $ns, $S4P::work_order_suffix);
    $this->set_config('work_order_pattern', $ns);

    # Child_sleep is a relic, used only in unusual performance circumstances
    $this->set_config('child_sleep', $ns, 0);

    ############# Configuration hashes
    $this->set_config_hash('downstream', $ns);
    $this->set_config_hash('token', $ns);
    $this->set_config_hash('reservations', $ns);
    $this->set_config_hash('commands', $ns);
    $this->set_config_hash('auto_restart', $ns);
    $this->set_config_hash('blackouts', $ns);
    $this->set_config_hash('virtual_jobs', $ns);

    return 1;
}
sub set_config {
    no strict 'refs';
    my ($this, $name, $ns, $default) = @_;
    my $var = $ns . '::cfg_' . $name;
    if (defined($$var)) {
        $this->{$name} = $$var;
    }
    elsif (defined($default)) {
        $this->{$name} = $default;
    }
}
sub set_config_hash {
    no strict 'refs';
    my ($this, $name, $ns, $default) = @_;
    my $var = $ns . '::cfg_' . $name;
    if (%{$var}) {
        $this->{$name} = \%$var;
    }
    elsif (defined($default)) {
        $this->{$name} = $default;
    }
}
#################################################################
# Set/get attributes
sub activity_monitor     {my $this=shift; defined($_[0]) 
                                  ? $this->{'activity_monitor'}=$_[0] 
                                  : $this->{'activity_monitor'} }
sub blackouts     {my $this=shift; defined($_[0]) 
                                  ? $this->{'blackouts'}=$_[0] 
                                  : $this->{'blackouts'} }
sub case_log     {my $this=shift; defined($_[0]) 
                                  ? $this->{'case_log'}=$_[0] 
                                  : $this->{'case_log'} }
sub commands     {my $this=shift; defined($_[0]) 
                                  ? $this->{'commands'}=$_[0] 
                                  : $this->{'commands'} }
sub child_sleep     {my $this=shift; defined($_[0]) 
                                  ? $this->{'child_sleep'}=$_[0] 
                                  : $this->{'child_sleep'} }
sub downstream     {my $this=shift; defined($_[0]) 
                                  ? $this->{'downstream'}=$_[0] 
                                  : $this->{'downstream'} }
sub end_job_interval     {my $this=shift; defined($_[0]) 
                                  ? $this->{'end_job_interval'}=$_[0] 
                                  : $this->{'end_job_interval'} }
sub failed_jobs  {my $this=shift; defined($_[0]) 
                                  ? $this->{'failed_jobs'}=$_[0] 
                                  : $this->{'failed_jobs'} }
sub failed_work_order_dir {my $this=shift; defined($_[0]) 
                           ? $this->{'failed_work_order_dir'}=$_[0] 
                           : $this->{'failed_work_order_dir'} }
sub ignore_duplicates {my $this=shift; defined($_[0]) 
                           ? $this->{'ignore_duplicates'}=$_[0] 
                           : $this->{'ignore_duplicates'} }
sub ignore_empty_files {my $this=shift; defined($_[0]) 
                           ? $this->{'ignore_empty_files'}=$_[0] 
                           : $this->{'ignore_empty_files'} }
sub input_work_order_suffix {my $this=shift; defined($_[0]) 
                           ? $this->{'input_work_order_suffix'}=$_[0] 
                           : $this->{'input_work_order_suffix'} }
sub job_deadline  {my $this=shift; defined($_[0]) 
                                  ? $this->{'job_deadline'}=$_[0] 
                                  : $this->{'job_deadline'} }
sub job_list  {my $this=shift; defined($_[0]) 
                                  ? $this->{'job_list'}=$_[0] 
                                  : $this->{'job_list'} }
sub log_statistics {my $this=shift; defined($_[0]) 
                                  ? $this->{'log_statistics'}=$_[0] 
                                  : $this->{'log_statistics'} }
sub lock_handle {my $this=shift; defined($_[0]) 
                                  ? $this->{'lock_handle'}=$_[0] 
                                  : $this->{'lock_handle'} }
sub max_children {my $this=shift; defined($_[0]) 
                                  ? $this->{'max_children'}=$_[0]
                                  : $this->{'max_children'} }
sub max_failures {my $this=shift; defined($_[0]) 
                           ? $this->{'max_failures'}=$_[0] 
                           : $this->{'max_failures'} }
sub max_failures_reached {my $this=shift; defined($_[0]) 
                           ? $this->{'max_failures_reached'}=$_[0] 
                           : $this->{'max_failures_reached'} }
sub num_running {my $this=shift; defined($_[0]) 
                           ? $this->{'num_running'}=$_[0] 
                           : $this->{'num_running'} }
sub open_slots {my $this=shift; defined($_[0]) 
                           ? $this->{'open_slots'}=$_[0] 
                           : $this->{'open_slots'} }
sub output_work_order_suffix {my $this=shift; defined($_[0]) 
                           ? $this->{'output_work_order_suffix'}=$_[0] 
                           : $this->{'output_work_order_suffix'} }
sub poll_dir {my $this=shift; defined($_[0]) 
                           ? $this->{'poll_dir'}=$_[0] 
                           : $this->{'poll_dir'} }
sub polling_interval {my $this=shift; defined($_[0]) 
                           ? $this->{'polling_interval'}=$_[0] 
                           : $this->{'polling_interval'} }
sub queued_jobs  {my $this=shift; defined($_[0]) 
                                  ? $this->{'queued_jobs'}=$_[0] 
                                  : $this->{'queued_jobs'} }
sub rename_retries {my $this=shift; defined($_[0]) 
                           ? $this->{'rename_retries'}=$_[0] 
                           : $this->{'rename_retries'} }
sub rename_retry_interval {my $this=shift; defined($_[0]) 
                           ? $this->{'rename_retry_interval'}=$_[0] 
                           : $this->{'rename_retry_interval'} }
sub reservations {my $this=shift; defined($_[0]) 
                           ? $this->{'reservations'}=$_[0] 
                           : $this->{'reservations'} }
sub restart_defunct_jobs {my $this=shift; defined($_[0]) 
                           ? $this->{'restart_defunct_jobs'}=$_[0] 
                           : $this->{'restart_defunct_jobs'} }
sub restart_interval {my $this=shift; defined($_[0]) 
                           ? $this->{'restart_interval'}=$_[0] 
                           : $this->{'restart_interval'} }
sub root {my $this=shift; defined($_[0]) 
                           ? $this->{'root'}=$_[0] 
                           : $this->{'root'} }
sub running_jobs {my $this=shift; defined($_[0]) 
                                  ? $this->{'running_jobs'}=$_[0] 
                                  : $this->{'running_jobs'} }
sub sort_jobs {
    my $this=shift; 
    if ( defined($_[0]) ) {
        $this->{'sort_jobs'}=$_[0];
        if ( ref($this->{'sort_jobs'}) ) {
            my @sort = @{$this->{'sort_jobs'}};
            my %sort_hash = map { ($this->{'sort_jobs'}->[$_], $_) } 0..$#sort;
            $this->{'sort_hash'} = \%sort_hash;
        }
    }
    return $this->{'sort_jobs'};
}
sub start_time {my $this=shift; defined($_[0]) 
                           ? $this->{'start_time'}=$_[0] 
                           : $this->{'start_time'} }
sub station_name {my $this=shift; defined($_[0]) 
                           ? $this->{'station_name'}=$_[0] 
                           : $this->{'station_name'} }
sub stop_interval {my $this=shift; defined($_[0]) 
                           ? $this->{'stop_interval'}=$_[0] 
                           : $this->{'stop_interval'} }
sub token {my $this=shift; defined($_[0]) 
                           ? $this->{'token'}=$_[0] 
                           : $this->{'token'} }
sub virtual_feedback  {my $this=shift; defined($_[0]) 
                           ? $this->{'virtual_feedback'}=$_[0] 
                           : $this->{'virtual_feedback'} }
sub virtual_jobs  {my $this=shift; defined($_[0]) 
                           ? $this->{'virtual_jobs'}=$_[0] 
                           : $this->{'virtual_jobs'} }
sub vanishing  {my $this=shift; defined($_[0]) 
                           ? $this->{'vanishing'}=$_[0] 
                           : $this->{'vanishing'} }
sub work_order_pattern {my $this=shift; defined($_[0]) 
                           ? $this->{'work_order_pattern'}=$_[0] 
                           : $this->{'work_order_pattern'} }
####################################################################
# add_station_to_perllib:
# Account for the fact the script will actually be run in a subdirectory, but
# may be expecting local files (like station-specific config files)
# Add to the environment for system calls
#------------------------------------------------------------------------
sub add_station_to_perllib {
    my $this = shift;
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
####################################################################
# apply_blackouts
# Remove jobs from queue that are blacked out for this time period

sub apply_blackouts {
    my $this = shift;
    my $rh_blackouts = $this->blackouts or return;
    my (@keep);

    # Get current time
    my @now = gmtime();
    my $hhmm = $now[2] * 100 + $now[1];  # Convert to HHMM format

    # Figure out which job_types are currently blacked out
    my %blackout_jobs;
    foreach my $job_type(keys %{$rh_blackouts}) {
        foreach my $blackout(@{$rh_blackouts->{$job_type}}) {
            if ($hhmm >= $blackout->[0] and $hhmm < $blackout->[1]) {
                $blackout_jobs{$job_type} = 1;
                last;
            }
        }
    }
    # Don't bother going any further unless some jobs are blacked out
    return unless scalar(keys %blackout_jobs);

    # Go through jobs and keep the ones that are not blacked out
    foreach my $job(@{$this->queued_jobs}) {
        my ($job_type) = S4P::parse_job_type($job, $CFG::cfg_work_order_pattern);
        push (@keep, $job) unless $blackout_jobs{$job_type};
    }
    $this->queued_jobs(\@keep);
    return \@keep;
}

# Check to see if files have arrived recently
# If not, raise an anomaly
sub check_activity_monitor {
    my $this = shift;
    my $activity_monitor = $this->activity_monitor or return 1;
    return $activity_monitor->check(@{$this->job_list});
}
sub check_max_failures {
    my $this = shift;

    # Initialize
    my %max_failures_reached = ();
    $this->max_failures_reached(\%max_failures_reached);

    my $max_failures = $this->max_failures or return;

    # Short circuit the process if no failed jobs
    my @failed_jobs = @{$this->failed_jobs} or return;

    my ($anomaly);
    # Case 1: $max_failures is a hash reference (not a regular scalar)
    # Check job-specific max_failures (key to the hash)
    if (ref $max_failures) {
        # Parse and count failed job types
        my %failed_jobs;
        foreach my $job(@failed_jobs) {
            my ($job_type) = S4P::parse_job_type($job, $this->work_order_pattern);
            $failed_jobs{$job_type}++;
        }
        # For each job_type with a max_failures set, see if it has been reached
        foreach my $job_type(keys %$max_failures) {
            my $n_fail = (exists $failed_jobs{$job_type}) ? $failed_jobs{$job_type} : 0;
            if ($n_fail >= $max_failures->{$job_type}) {
                $max_failures_reached{$job_type} = $n_fail;
            }
        }
        $anomaly = "At max failures: " . join(',', keys %max_failures_reached)
            if (%max_failures_reached);
    }
    # Total max_failures case ($max_failures is a scalar)
    elsif (scalar(@failed_jobs) >= $max_failures) {
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
}
sub check_host {
    my $this = shift;
    # Check to see if I am on the right machine to start up this station
    my $valid_host = $this->{'host'} or return 1;
    if ($valid_host ne hostname()) {
        S4P::logger('FATAL', "You must be on $valid_host to start this station (see station.cfg)");
        return;
    }
}
sub check_open_slots {
    my $this = shift;
    my $rh_reservations = $this->reservations or return;
    my $ra_running_jobs = $this->running_jobs;
    my $max_children = $this->max_children;
    my (%running, %open);
    $running{WALK_IN} = 0;
    my ($job_type, $job_id, $n_reserved);
    foreach my $job(@$ra_running_jobs) {
        ($job_type) = S4P::parse_job_type($job, $CFG::cfg_work_order_pattern);
        $job_type = WALK_IN unless ($rh_reservations->{$job_type});
        $running{$job_type}++;
    }
#   open(type) = res(type) - running(type)
#   open(walk_in) = max_children - sum(max(res(type),running(type)) - running(walk_in)
    my $n_walk_in = $max_children - $running{WALK_IN};
    while (($job_type, $n_reserved) = each %$rh_reservations) {
        $running{$job_type} = 0 unless (exists $running{$job_type});
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
    $this->open_slots(\%open);
    return %open;
}

sub check_user {
    my $this = shift;
    my $valid_user = $this->{'user'} or return 1;
    my $username = ($^O =~ /Win32/) ? $ENV{'USERNAME'} : getpwuid($<);
    if ($valid_user ne $username) {
        S4P::logger ('FATAL', "Only user $valid_user can start this station (see station.cfg)");
        return;
    }
    return 1;
}
sub find_command {
    my ($this, $job_type) = @_;
    my %commands = %{$this->commands};    
    # Go directly to value if no regex in command keys
    return $commands{$job_type} if (! $this->{'cmd_has_regex'});
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
# Is the station too busy to spawn new jobs?
sub is_busy {
    my $this = shift;
    my $max_children = $this->max_children or return 0;
    if ($this->num_running >= $max_children) {
        S4P::logger("DEBUG", "Max number of running children ($max_children) reached, skipping remaining new jobs for now...");
        return 1;
    }
    return 0;
}

sub prestart_check {
    my $this = shift;

    # Check to see if this station is marked as disabled. If so, exit quietly.
    if ($this->{'disable'}) {
        S4P::logger("WARN", 'This station is currently disabled with $cfg_disable. To enable, set $cfg_disable to zero or remove it. Exiting...');
        return;
    }

    # Check to see if I am the right user to start up this station
    $this->check_user() or return;

    # Check to see if we are on the right host (on NFS instances)
    $this->check_host() or return;

    # Check to see if there are any commands specified
    unless ($this->commands) {
        S4P::logger('FATAL', "No commands specified, exiting...");
        return;
    }
    return 1;
}

#========================================================================
# lock: open a station.lock file to prevent duplicate stationmasters
# Also writes the PID to the station.pid file.
#------------------------------------------------------------------------
sub lock {
    my $this = shift;
    # Open lock file to prevent other stationmasters from running here
    my $lockfile = "station.lock";
    open(LOCK_FH, "+> $lockfile") or die "Cannot open $lockfile: $!";
    flock(LOCK_FH, 2 | 4) or die "Cannot write-lock $lockfile: $!";
    my $pid_str = "pid=$$\n"; # Write PID just for debugging
    my $written = syswrite(LOCK_FH, $pid_str, length($pid_str));
    die "syswrite failed: $!\n" unless $written == length($pid_str);
    $this->{'lock_handle'} = *LOCK_FH;

    # Write to PID file (used for starting/stopping)
    open(PID, ">station.pid") or die "Cannot write to station.pid: $!";
    print PID $pid_str;
    close PID;
}

##########################################################################
# log_performance():  log user and system time for parent and child, along
#   with memory.
##########################################################################
sub log_performance {
    my $this = shift;
    return unless $this->{'monitor_performance'};
    my @times = times();
    my @mem = `ps -p $$ -o sz`;
    shift @mem;
    chomp(@mem);
    S4P::logger("INFO", "User=$times[0] Sys=$times[1] ChldUser=$times[2] ChldSys=$times[3] Mem=$mem[0]");
    return 1;
}

# Poll for work orders
sub poll {
    my $this = shift;
    # Check our lock file to see if it is still there
    S4P::perish(6, "Lost lock file!") unless (-r "station.lock");


    # First look for STOP, RESTART, VANISH, and RECONFIG so that 
    # they're recognized even with the standard .wo file name extension
    my @special_files = map {glob("DO.$_.*wo")} qw(STOP RESTART RECONFIG VANISH);
    my %special_files = map{($_=>1)} @special_files;
    my @new_files = @special_files;

    # Then look for Priority jobs; note explicit sort function to avoid
    # interpretation of glob as the sort function indicator
    my @priority_files = glob($this->{priority_work_order_pattern});
    my @sort_pri_files = sort {$a cmp $b}  @priority_files;
    push @new_files, @sort_pri_files;

    # Look for currently running jobs
    my @running_jobs = glob('RUNNING.*');
    $this->{'running_jobs'} = \@running_jobs;
    $this->num_running(scalar(@running_jobs));

    # Get normally queued jobs; exclude directories and special files
    my @queued_jobs = grep {(-f $_) && !exists($special_files{$_})} 
        glob($this->{input_work_order_pattern});
    $this->queued_jobs(\@queued_jobs);

    # Pull over remote polling jobs (this adds them to the queue)
    $this->remote_poll if $this->poll_dir;

    # Need to look for failed jobs if we are:
    #   1) stopping stations on max_failures
    #   2) suppressing virtual job creation if failures exist
    #   3) restarting failed jobs automatically
    if ($this->max_failures || $this->virtual_feedback
        || $this->{'auto_restart'}) {
        my @failed_jobs = grep !/^FAILED.WORK_ORDERS/, <FAILED.*>;
        $this->{'failed_jobs'} = \@failed_jobs;
    }

    # Fill max_failures hash
    $this->check_max_failures();

    # Requeue failed jobs if cfg_auto_restart_interval is set
    $this->restart_failed_jobs();

    # Add any virtual ("self-seeding") jobs
    $this->create_virtual_jobs();

    # If we are ignoring empty work orders, take them out
    $this->screen_empty_files if $this->ignore_empty_files;

    # Apply blackouts if applicable
    $this->apply_blackouts() if $this->blackouts;

    # Sort all of the queued jobs
    push @new_files, $this->sort_queue();
    $this->job_list(\@new_files);
    return @new_files;
}

# Redirect logging output to specified logfile
sub redirect_logfile {
    my ($this) = @_;
    S4P::redirect_log($this->{'logfile'}) unless ($this->{'logfile'} eq '-');
}
sub remote_poll {
    my $this = shift;
    return unless ($this->poll_dir);
    my @remote_jobs = grep {-f $_} 
        glob($this->poll_dir . '/' . $this->{input_work_order_pattern});
    foreach my $job(@remote_jobs) {
        if (move($job, '.')) {
            push @{$this->queued_jobs}, basename($job);
        }
        else {
           S4P::logger('ERROR', "Failed to move remote job $job to '.': $!");
        }
    }
}
#========================================================================
# require_command_packages(%commands)
#     Check commands and include Perl packages as required
#------------------------------------------------------------------------
sub require_command_packages {
    my $this = shift;
    my @commands = values %{$this->commands};
    my @perl_modules = grep {/::/} @commands;
    return 1 unless @perl_modules;
    foreach my $cmd(@perl_modules) {
        my @cmd_args = split ' ', $cmd;
        my ($pkg, $function) = split /::/, $cmd_args[0];
        if (! require "$pkg.pm") {
            S4P::logger("FATAL", "Failed to include Perl package $pkg");
            return;
        }
    }
    return 1;
}
sub restart_failed_jobs {
    my $this = shift;
    my $ra_jobs = $this->{'failed_jobs'} or return;
    my $rh_restart_cfg = $this->{'auto_restart'} or return;
    my %restart;
    my @requeued;
    my $n_jobs = scalar(@$ra_jobs);
    return 0 unless ($n_jobs);
    my $now = time();
    my $station_dir = getcwd();
    S4P::logger('DEBUG', "Attempting to restart $n_jobs failed jobs at $now");
    foreach my $job(@$ra_jobs) {
        my ($job_type, $job_type_and_id, $priority, $rerun) = 
                S4P::parse_job_type($job, $this->work_order_pattern);
        push @{$restart{$job_type}}, $job;
        # Skip if no entry in restart config hash
        next unless (exists $rh_restart_cfg->{$job_type});
    }

    # Foreach job_type, restart (gently) if ready
    foreach my $job_type(keys %restart) {
        S4P::logger('DEBUG', "Restarting job_type $job_type");
        my $clock_file = "RESTART_CLOCK.$job_type";

        my $restart_fn = $this->restart_function($job_type);
        unless ($restart_fn) {
            S4P::logger('ERROR', "Could not get restart_function for job_type $job_type");
            next;
        }
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
            my $job_dir = "RUNNING.$job_info";
            if (-d $job_dir) {
                S4P::logger('DEBUG', "Scout job $job_dir is still running");
                next;
            }
            # Check to see if scout job is either FAILED or not yet started
            ($job_dir) = glob("FAILED.$job_info.*");
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
                    my $restarted = &$restart_fn();
                    if ($restarted) {
                        S4P::logger('DEBUG', "Restarted job $job");
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
                    my $orig_work_order = &$restart_fn();
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
    push (@{$this->{regular_jobs}}, @requeued) if (scalar(@requeued));
    return @requeued;
}
sub restart_function {
    my ($this, $job_type) = @_;
    # No restart for this job type
    return unless (exists $this->{'auto_restart'}->{$job_type});

    # Restart, but no script specified
    unless (exists($this->{'auto_restart'}->{$job_type}->{'script'})) {
        S4P::logger('DEBUG', "No script specified for $job_type");
        return \&S4P::restart_job;
    }

    # Custom script for this job_type. 
    # N.B.:  no arguments will be passed!
    my $script = $this->{'auto_restart'}->{$job_type}->{'script'};
    my $fn = sub {
            my ($status, $pid, $owner, $orig_wo, $comment) = S4P::check_job();
            S4P::logger('INFO', "Restarting job with script $script");
            my $rc = S4P::exec_system($script); 
            return ($rc ? 0 : $orig_wo);
        };
    return $fn;
}
    
sub screen_empty_files {
    my $this = shift;

    my (@legit, @empty);
    foreach my $job(@{$this->queued_jobs}) {
        if ((-s $job) || ($job =~ /^DO\.(STOP|RECONFIG|RESTART|VANISH)\./) ) {
            push(@legit, $job);
        }
        else {
            push(@empty, $job);
        }
    }
    $this->queued_jobs(\@legit);
    return unless (@empty);
   
    my $anomaly = join("\n", @empty, '');
    # Unexpected zero-length work orders can indicate a sick filesystem
    S4P::raise_anomaly('SLOW_FS', '.', 'WARN',
        "Unexpected zero-length work orders:\n$anomaly", 0);
}

# Set umask for file and directory creation
sub set_umask {
    my ($this, $umask) = @_;
    umask( (defined($umask)) ? oct($umask) : $this->{'umask'} );
}

sub sort_job_list {
    my ($this, @jobs) = @_;
    return () unless(@jobs);
    my $sort_jobs = $this->sort_jobs;
    if (! $sort_jobs) {
        S4P::logger('DEBUG', "Sorting jobs alphabetically");
        return sort {$a cmp $b} @jobs;
    }
    elsif (ref $sort_jobs) {
        S4P::logger('DEBUG', "Sorting by job type");
        my %sort_hash = %{$this->{'sort_hash'}};
        # Schwartzian transform:
        # Split the job and take the second element
        # Then sort on the number in the precomputed sort hash
        my @sort = map {$_->[0]}
                   sort { $sort_hash{$a->[1]} <=> $sort_hash{$b->[1]} }
                   map {[ $_, (split /\./)[1] ]} @jobs;
        return @sort;
    }
    elsif ($sort_jobs eq 'FIFO') {
        S4P::logger('DEBUG', "Sorting jobs by FIFO");
        return sort {(-M $b) <=> (-M $a)} @jobs;
    }
    elsif ($sort_jobs =~ /::/) {
        # Strip off function to get module for require
        my @module = split('::', $sort_jobs);
        pop @module;
        my $req = join('::', @module);
        eval "require $req" or S4P::perish(2, "Cannot require sort module $req: $!");
        S4P::logger('DEBUG', "Sorting jobs using custom sort $sort_jobs");
        return sort $sort_jobs @jobs;;
    }
    else {
        S4P::logger("WARN", "Unrecognized job sort type: $sort_jobs");
    }
    return @jobs;
}
sub sort_queue {
    my $this = shift;
    my @jobs = @{$this->queued_jobs};
    return $this->sort_job_list(@jobs);
}
###################################################################

sub startup {
    my ($this, $umask, $tee, $once) = @_;
    $this->set_umask($umask);
    $this->redirect_logfile() unless $tee;

    # Check valid user, host, presence of commands
    $this->prestart_check() or return;

    # Open counter log
    unless ( S4P::open_counter($this->{'counter_logfile'}) ) {
        S4P::logger('FATAL', "Could not open counter logfile");
        return;
    }
    $this->require_command_packages() or return;

    # Check to see if any of the command keys have regular expression characters
    $this->{'cmd_has_regex'} = grep /[\.\*\^\$]/, (keys %{$this->commands});

    $this->{'start_time'} = time();
    S4P::logger("INFO", "Starting up stationmaster with config file $this->{'config_file'} on host " . hostname());

    $! = 1;  # Turn on autoflush

    $this->add_station_to_perllib();

    # Setup input work order pattern
    $this->{'input_work_order_pattern'} = $this->work_order_pattern ||
         S4P::work_order_pattern($S4P::work_order_prefix, 
                                 $this->input_work_order_suffix);
    $this->{'priority_work_order_pattern'} = 'PRI?.' . 
         $this->{'input_work_order_pattern'};

    S4P::logger("DEBUG", "Looking for files like $this->{'input_work_order_pattern'}");
    # Run in non-forking mode if we are just doing one job and out
    $this->max_children(0) if $once;
    $this->{'activity_monitor'} = new S4P::ActivityMonitor(
        'max_interval' => $this->{'max_interval'}) if ($this->{'max_interval'});
    # Restart defunct jobs on startup if configured to do so
    S4P::restart_defunct_jobs() if ($this->{'restart_defunct_jobs'});
    return 1;
}
# Virtual jobs are "self-seeding".
# They do not require a work order.  Instead stationmaster will
# create work orders on its own up to the limit specified.
# Thus, it takes the configuration hash of number of jobs for a given
# job type, subtracts the number of currently pending or running jobs
# of that job type and creates the resulting number of work orders.
# CAUTION:  Works only with "standard" job names, like DO.*
sub create_virtual_jobs {
    my $this = shift;
    my $rh_virtual_jobs = $this->virtual_jobs or return;
    my $ra_pending_jobs = $this->queued_jobs;
    my $ra_running_jobs = $this->running_jobs;
    my $ra_failed_jobs = $this->failed_jobs;
    my $feedback = $this->virtual_feedback;
    my (@current, %extant);
    my $i;
    push (@current, @$ra_pending_jobs, @$ra_running_jobs);
    # Add failed jobs if feedback switch is set
    push (@current, @$ra_failed_jobs) if $feedback;
    foreach my $job(@current) {
        my ($job_type) = S4P::parse_job_type($job, $this->work_order_pattern);
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
                $this->input_work_order_suffix);
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
sub vanish {
    my $this = shift;

    # Check to see if station is configured to allow vanishing
    unless ($this->vanishing) {
        S4P::raise_anomaly('NO_VANISH', '.', 'ERROR',
            "This station is not configured to allow vanishing", 2);
        return;
    }
    $this->poll();
    # Check to see if there are any running jobs first
    if (scalar(@{$this->running_jobs}) > 0) {
        S4P::logger('WARN', "Cannot vanish until all running jobs are done or failed");
        return 1;   # "Sub-nominal" case: didn't vanish, but didn't fail either
    }

    # rmtree does not work on current dir, so save the cwd and go up one.
    # Be vewy, vewy careful...
    my $stadir;
    unless (($stadir = getcwd()) || !(-f "$stadir/station.cfg")) {
        S4P::logger('ERROR', "Cannot get current directory: $!");
        return;
    }
    unless (chdir('..')) {
        S4P::logger('ERROR', "Cannot chdir to parent directory: $!");
        return;
    }
    # Remove the directory
    rmtree($stadir);
    if (-d $stadir) {
        S4P::logger('ERROR', "Failed to remove station directory: $!");
        return;
    }
    # ...and the directory is gone so we're outta here.
    exit(0);
}

# Sleep, but keep an eye out for stop or restart work orders
# We can handle STOP work orders ourselves, but if restart
# is required, return control to the main program.
sub watchful_sleep {
    my $this = shift;
    my $poll = $this->polling_interval;
    my $check = $this->stop_interval;
    # Compute number of integral sub-intervals, plus remainder
    my $n = int($poll / $check);

    # Modular remainder after N polling subintervals
    my $rem = $poll % $check;
    my $stop_file = 'DO.STOP.NOW.wo';
    my $vanish_file = 'DO.VANISH.NOW.wo';
    my $restart_file = 'DO.RESTART.NOW.wo';
    # Sleep for whole intervals, but check each time for STOP
    # or RESTART work orders
    foreach (1..$n) {
        return($stop_file) if (-f $stop_file);
        return($restart_file) if (-f $restart_file);
        return($vanish_file) if (-f $vanish_file);
        sleep($check);
    }
    return($stop_file) if (-f $stop_file);
    return($restart_file) if (-f $restart_file);
    sleep($rem) if ($rem);
    if ($this->restart_interval) {
        if ( (time() - $this->start_time) > $this->restart_interval) {
            S4P::write_file($restart_file, "Restart at " . gmtime() . "\n");
            return $restart_file;
        }
    }
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

