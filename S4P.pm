=head1 NAME

S4P.pm - package of general utilities to support S4P

=head1 SYNOPSIS

=for roff
.nf

use S4P;

($error_string, $errcode) = S4P::exec_system($command, @args);

($error_string, $errcode) = S4P::nervous_system($signal_file, $interval, $command, @args);

$rc = S4P::fork_command($command, @args);

$rc  = S4P::move_file($source, $destination);

S4P::logger($severity,  $message, [$outfile]);

S4P::redirect_log($redirect);

S4P::raise_anomaly($anomaly_type, $dir, $severity, $message, $mode);

S4P::clear_anomaly($anomaly_type, $dir);

S4P::job_message($message);

$timestamp = S4P::timestamp();

$formatted_time = S4P::format_time(@time_array);

$formatted_time = S4P::format_localtime($epoch_time);

$formatted_time = S4P::format_gmtime($epoch_time);

$unique_id = S4P::unique_id();

$rc = read_safe_config($file, [$namespace]);

$rc = set_config_var($obj, $name, $namespace, $default);

$s = S4P::read_file($file);

$rc = S4P::write_file($file, $string);

S4P::perish($exit_code, $string);

$rc  = S4P::open_counter($file);

S4P::counter($type);

S4P::check_station($directory);

($job_type, $job_id, $priority, $rerun) = S4P::parse_job_type($filename, [$pattern])

($status, $pid, $owner, $original_work_order, $comment) = S4P::check_job($directory, $check_pid);

$is_defunct = S4P::job_is_defunct($directory);

S4P::alert_job($dir, $alert_type)

S4P::end_job($dir, $alert_type)

S4P::terminate_job ($dir);

S4P::suspend_job_child ($dir);

S4P::resume_job_child ($dir);

S4P::signal_job_child ($dir, $signal)

S4P::fail_job($job_id, $error_message, $exit_code, $case_log, $rename_retries, $rename_retry_interval, $token)

S4P::rename_job_dir ($old, $new, $retries, $retry_interval)

S4P::restart_job()

S4P::restart_defunct_jobs($case_log, $rename_retries, $rename_retry_interval)

S4P::remove_job()

S4P::stop_station ($gently);

S4P::snore($seconds, $message);

S4P::await($how_long, $interval, $message, $rs_function, $arg, $arg...);

S4P::repeat_work_order($old_work_order, [$suffix]);

S4P::send_downstream($logfile, $rh_downstream, $priority, [$root, $work_order_suffix])

S4P::log_case($type, $case_info, [$station, $job])

$res = S4P::authenticate_unix_user($userid, $passwd);

@names = S4P::criteria_names($odltree);

$criteria_value = S4P::criteria_value($odltree, $name);

$criteria_type = S4P::criteria_type($odltree, $name);

%criteria = S4P::criteria_hash($odltree);

($login, $password) = S4P::get_ftp_login($host);

$token = S4P::request_token($token_dir, $jobpath, $job_type_and_id, 
  $wait, $interval);

$token = S4P::grant_token($work_order_file);

S4P::release_token($token);

$response = S4P::http_get($url, $user, $password);

=head2 DEPRECATED

S4P::suspend_job ($dir);

S4P::resume_job ($dir);

=head1 DESCRIPTION

=over 4

=item exec_system($command, @args)

Executes a 'system' command, with error processing.  
The return is a two element array in array context:  the first element is a 
string describing the error, or nothing if successful; the second element is
the actual error code.
In scalar context, the return is an error code.

=item nervous_system($signal_file, $interval, $command, @args)

This is like exec_system, except it checks every b<$interval> seconds
for the presence of file b<$signal_file>.  If the file shows up, it calls
terminate_job().  Thus, it is meant for stationmaster jobs only.
Note that this does not actually use system(), but rather a fork/exec.

=item fork_command($command, @args)

Forks and then execs the command with command line args. It returns
1 to the parent if the fork/exec were executed (it doesn't know or care if the
command that was exec'd was successful).  It returns 0 if unsuccessful.
If it gets the 'No more processes error', it will try again every 6 seconds,
for 1000 times before giving up.

=item move_file($source, $destination)

Copies a file from the source to the destination.
It returns 1 if successful, 0 on error.

=item logger($severity, $message, [$outfile])

Outputs a message to STDERR in a fixed format:  timestamp, 
process_id, severity/type of error, application and message.
It always returns 1.  
Standard severities are: FATAL, ERROR, WARN, INFO and DEBUG in that order.  
Messages are actually logged if their severity exceeds the 
textual severity of S4PM_LOG_LEVEL environment variable.
For example, if the setting is "WARN", only WARN, ERROR and FATAL 
messages will be written.
If S4PM_LOG_LEVEL is not set, it defaults to INFO (i.e., all but DEBUG
messages will be written.)  
Unrecognized severities are assumed to be ERROR level.

In some cases, we want to override the redirected log stream and
write directly to a file, hence the outfile argument.

=item redirect_log($redirect)

Redirects logging either to a file (if a regular string variable) 
or to a user-specified function (if a reference).
The function can expect to get the following parameters passed, in order:
$timestamp, $process_id, $login, $severity, $application, $message.

Example:  S4P::redirect_log(\&output_fn);

=item raise_anomaly($anomaly_type, $dir, $severity, $message, $mode)

Raises an anomaly by writing to a signal file of the given type.
The filename will be "ANOMALY-type.log"; each instance of the 
anomaly will result in a line having the format:

YYYY/MM/DD HH:MI:SS severity> message

$mode can take the following values:
  0: append to log
  1: overwrite log
  2: if log exists, just return

raise_anomaly() also calls S4P::logger to log the message.

=item clear_anomaly($anomaly_type, $dir)

Clears an anomaly by unlinking the anomaly file.

=item job_message($message)

Writes up to 65 characters to a job.message file for display by the
tkstat.pl interface.

=item timestamp()

Returns the current local time in a standard format.
format_localtime returns a local epochal time in a standard format.
format_localtime returns a GMT epochal time in a standard format.
unique_id returns a concatenation of the local time and the process_id.

=item read_safe_config($file, [$namespace])

Replaces read_config_file. 
Uses Safe module to read in a configuration file.
Optional namespace can be specified (Default is 'CFG');

=item set_config_var($obj, $name, $namespace, $default);

Sets an attribute in an object, based on its configuration variable setting,
I<assuming> that the attribute "foo" has configuration variable "cfg_foo".
The I<$obj> argument is the object to modify; I<$name> is the attribute name;
I<$namespace> should be the namespace from B<read_safe_config>; and 
I<$default> is an optional default value.

=item read_config_file($file)

I<Deprecated in favor of read_safe_config.>
Reads in a config file and evals it, exporting (by
force) into the caller's namespace.  Only parameter = value; syntax is
supported, though the value can be arbitrarily complex.  The parameter
variable can be of any basic perl type:  scalar, array or hash.
It returns 1 on success, 0 on failure.

This is deprecated in favor of the Safe module.  Unfortunately, a lot of
the older S4P code still uses it.

=item read_file($file)

Simple utility routine to read a whole file (newlines
and all) in one fell swoop.  The main reason for using it is to have
the appropriate error logging, etc.  It is particularly useful for
calling objects like PDR which expect a text string on creation.
It returns a string on success, 0 on failure.

=item write_file($file, $string)

Simple utility routine to write a whole string (newlines
included) in one fell swoop.  The main reason for using it is to have
the appropriate error logging, etc.
It returns 1 on success, 0 on failure.

=item perish($exit_code, $message)

Replacement for die() that calls logger before exiting.
It does not return.

=item open_counter, counter

Write simple messages to the 
station counter log, which logs job start and completion.

=item check_station($directory)

Checks to see if a station is "up", i.e., has a running stationmaster.
It attempts to obtain a lock on station.lock, which should be refused if a
a stationmaster is running (which holds the lock).

=item check_job ($directory, $check_pid)

Gets information on a given job (pid, owner, status, original work order) from 
a job.status file.  If the $check_pid argument is true, then it also runs "ps"
to see if the process id is still active.  If not, it replaces RUNNING with
DEFUNCT in the status.

=item job_is_defunct($directory)

This calls check_job() with the $check_pid argument and returns 1 if the
job is DEFUNCT, i.e., in a RUNNING.* directory, with RUNNING status, but no
longer actually running on the system.  (This is common when the system
crashes or reboots itself.)

=item write_job_status ($dir, $status, $orig_wo, $comment, $owner, $pid)

Writes information to the job.status file.

=item alert_job ($directory, $alert_type)

Sends either a signal (single-user mode) or signal file (multi-user mode) to 
an active job.  Valid types are "END", "SUSPEND", "RESUME".

=item end_job($directory)

Ends a job by calling alert_job with alert_type = END.

=item terminate_job ($directory)

Terminates a job's child, i.e., the command being executed.

=item signal_job_child ($directory, $signal)

Signal the child (or grandchild in some cases) of the job running in a
directory.  Valid signals are 'STOP' (suspend job), 'CONT' (resume job).
Also valid is 9, i.e., terminate; this is used by terminate_job().
This also updates the job_status file to the new status (SUSPENDED or RUNNING).
It does not update in the terminate case, as that is done by stationmaster.

=item suspend_job_child ($directory)

Sends a SIGSTOP signal to a job child, i.e., the actual script being run.

=item resume_job ($directory)

Sends a SIGCONT signal to a job child, i.e., the actual script being run.

=item suspend_job ($directory)

Sends a SIGSTOP signal to a job (i.e., the forked stationmaster
process executing the command).  Deprecated as it does not always suspend the
children.  Use suspend_job_child instead.

=item resume_job ($directory)

Sends a SIGCONT (resume) signal to a job 
(i.e., the forked stationmaster process executing the command).
Deprecated as it does not always suspend the
children.  Use resume_job_child instead.

=item fail_job($job_id, $error_message, $exit_code, $case_log, $rename_retries, $rename_retry_interval, $token)

Renames a RUNNING directory to FAILED and writes to various logs.
$job_id is the job identifier I<after> the "RUNNING." prefix, i.e.,
that starting with the job_type.
$error_message is written when S4P::perish is called, with $exit_code as the
exit code.
$case_log is the case-based reasoning log to write to.
$rename_retries is the number of times to attempt to rename the directory
to FAILED.*, at an interval of $rename_retry_interval.


N.B.:  you must be in the RUNNING directory to call this.
However, you will end up in the parent directory afterward.

=item rename_job_dir($old, $new, $retries, $retry_interval)

Renames a job directory, usually from a RUNNING.* pattern to a FAILED.* pattern.
Typically used only by stationmaster.

=item restart_job ()

Copy all log files and work orders up one directory.

=item restart_defunct_jobs($rename_retries, $rename_retry_interval, $token)

Restart jobs that are defunct, i.e., there is still a RUNNING directory, but
the process_id is gone (usually due to a system crash).
This returns the number of jobs restarted.
$case_log is the case-based reasoning log to write to.
$rename_retries is the number of times to attempt to rename the directory
to FAILED.*, at an interval of $rename_retry_interval.
$token

N.B.:  You must be in the station directory when you call this.

=item remove_job ()

Remove all files from failed directory.

=item stop_station ($gently)

Shutdown a station.  If $gently is non-zero, a DO.STOP.NOW.wo work order 
is used, otherwise, the pid is hunted down and killed.

=item snore($seconds, $message)

Snore is just like sleep, except it's noisy, writing a little file called
sleep.message.$$ with a message saying it is going to sleep and why.

=item await($how_long, $interval, $message, $rs_function, $arg, $arg...);

Await waits for $how_long, checking at regular intervals ($interval) using
a user-specified function and user-specified arguments.  The user specified
function should return non-zero when the thing waited for shows up, and that
return code will be passed back to the calling function.

In the midst of all this, await uses snore, so that there is a little file 
describing what it is waiting for.

Example:  S4P::await(120, 5, "Waiting for file $ARGV[0] to show up...", \&check_for_file, $ARGV[0]);

 sub check_for_file {
     my $file = shift;
     return (-f $file);
 }

=item repeat_work_order($work_order, [$suffix])

This copies the input work order name, in the form DO.jobtype.jobid to an
output work order form, i.e., jobtype.jobid.wo.  The default .wo suffix
can be overridden if desired.

=item send_downstream($logfile, $rh_downstream, $priority, [$root, $suffix])

This sends output work orders (recognized by $suffix) to the downstream
stations specified in the rh_downstream hash (see stationmaster man page
for more details.)

=item log_case($case_log, $type, $exit_code, $info, [$station, $job_type, $job_id])

This logs a case in the case based reasoning log.
The station, job_type and job_id will be inferred from the current
directory if not specified.  The $case_log is the full pathname to the case
database file.  The type is one of the following:
  F = Fault
  R = Recovery action
  D = Diagnosis
  M = Manual override or action
The $info is free format information about the case.

=item authenticate_unix_user($userid, $passwd)

Simple utility that authenticates a UNIX user using the /etc/passwd file.
It returns a 1 if the userid and password are correct; it returns a zero
otherwise.

=item criteria_names($odltree)

Given an ODL tree object, returns an array of specialized criteria names or
undef if none exist.

=item criteria_value($odltree, $name);

Given an ODL tree object and a specialized criteria name, returns the value
corresponding to that name or undef if not found.

=item criteria_type($odltree, $name);

Given an ODL tree object and a specialized criteria name, returns the type
corresponding to that name or undef if not found.

=item criteria_hash($odltree);

Given an ODL tree object, returns a hash of specialized criteria, associated
data types, and values. The hash keys are pairs of specialized criteria names
and data types/versions (separated by a pipe as in 'CHANNELS|MOD021KM.004') 
and the hash values are the criteria values for that criteria name associated 
with that data type and version.

=item get_ftp_login($host)

Get login and password from the .netrc file for a given machine

=item request_token($token_dir, $jobpath, $job_type_and_id, $wait, $interval)

Requests a token to proceed with running a job (normally called only by
stationmaster).  $token_dir is actually a station running s4p_token.pl.  
s4p_token.pl will rename the work order to GRANTED.$job_type_id.$sta_id.tkn
in the station directory.  The first part of the path, job_type_id, is actually
the combination of job_type and job_id.  The second part, sta_id, is a 32-bit
checksum of the station path.  

When request_token() sees this file appear, it
considers the token granted and returns the full, absolute path to the 
GRANTED.* file.  This token should later be released using release_token().

=item grant_token($work_order_file)

This parses the work_order_file which was written by request_token() and
converts into a granted token by copying it to the directory above with the
name GRANTED.$job_id.tkn where $job_id is the combination of the requestor's
job_type, job_id and station_id (checksum of station directory).

See also L<s4p_token.pl.1>.

=item release_token($tokenfile)

Releases a token by simply unlinking the token file.
Returns non-zero if file is already gone or is successfully unlinked.
Failure to unlink an existing file returns 0.

=item http_get($url, $user, $password);

Utility routine to obtain a URL given an optional username and password.
Returns result in a string, or undef if an error is encountered.
In the latter case, the error response will be written to the log.

N.B.:  If you use this feature, you will need the following packages
installed:

o LWP::UserAgent

o HTTP::Request

o HTTP::Response

=back

=head1 EXAMPLES

=for roff
$pdr = new S4P::PDR('text'=> S4P::read_file($filename));

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# S4P.pm,v 1.28 2009/02/01 21:48:00 clynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P;
use Time::Local;
use FileHandle;
use File::Copy;
use File::Basename;
use Cwd;
use Safe;
use POSIX ":sys_wait_h";
use S4P::OdlTree;
use strict;
BEGIN {
    if ($^O =~ /Win32/i) {
        require Win32;
        require Win32::Process;
    }
}
my $rf_log_fn;
%S4P::log_levels = (
    'FATAL' => 1,
    'ERROR' => 2,
    'WARN' => 3,
    'WARNING' => 3,
    'INFO' => 4,
    'DEBUG' => 5,
);

%S4P::sig_num = ();
$S4P::work_order_suffix = 'wo';
$S4P::work_order_prefix = ($^O =~ /Win32/i) ? 'DO' : '{DO,REDO}';
$S4P::work_order_pattern = work_order_pattern();
$S4P::failed_job_pattern = '^FAILED.(PRI\d\.)*';
$S4P::running_job_pattern = '^RUNNING.(PRI\d\.)*';

2;

#####################################################################
# work_order_pattern: S4P-standard way of obtaining the work order pattern
# throughout.
#####################################################################
sub work_order_pattern {
    my ($prefix, $suffix) = @_;
    $prefix ||= $S4P::work_order_prefix;
    $suffix ||= $S4P::work_order_suffix;
    return ($prefix . '.*.' . $suffix);
}
##############################################################################
# repeat_work_order
#=============================================================================
sub repeat_work_order {
    my $old_name = shift;
    my $suffix = shift || 'wo';
    my ($prefix, $job_type, $job_id, $discard) = split('\.', $old_name, 4);
    # Add process_id for uniqueness
    my $new_job_id = "$job_id.$$";
    my $new_name = sprintf("%s.%s.%s", $job_type, $new_job_id, $suffix);
    if (! copy($old_name, $new_name)) {
        S4P::logger('ERROR', "Failed to copy $old_name to $new_name: $!");
        return 0;
    }
    else {
        return 1;
    }
}

#####################################################################
# move_file:  convenience routine for copying a file from one system to another
#####################################################################
sub move_file {
    my($source, $destination) = @_;
    if ($destination =~ m#^rcp://#) {
        $destination =~ s#^rcp://##;  # Strip off url header
        $destination =~ s#/#:/#;       # Convert / to :/ between machine and dir
        my $rc = exec_system ("rcp", $source, $destination);
        if ($rc) {
            logger("ERROR", "Failed to move file $source to $destination: $rc");
            return 0;
        }
        return 1;
    }
    my $rc = copy($source, $destination);
    if (! $rc) {
        logger("ERROR", "Failed to move file $source to $destination: $!");
    }
    return $rc;
}
#####################################################################
# logger:  S4P-standard routine for reporting errors
#####################################################################
sub logger {
    my ($type, $message, $logfile) = @_;

    my $log_level = $S4P::log_levels{'DEBUG'} if $ENV{'OUTPUT_DEBUG'};
    $log_level ||= $S4P::log_levels{$ENV{'S4PM_LOG_LEVEL'}} 
        if $ENV{'S4PM_LOG_LEVEL'};
    $log_level ||= $S4P::log_levels{'INFO'};
    my $this_level = (exists $S4P::log_levels{$type}) 
                     ? $S4P::log_levels{$type} : $S4P::log_levels{'ERROR'};
    return 1 if ($this_level > $log_level);

    my $login = getlogin() || (getpwuid($<))[0];

    # Get application name from command line
    my $app = $0;

    # Strip off leading directory path component
    $app =~ s#.*/##;

    unless ($message) {
        my ($pkg, $fname, $line) = caller();
        $message = "$fname, $pkg at line $line";
    }
    chomp($message);

    # Sometimes we want to log to a specific file
    # E.g., when redirecting to GUI dialog, we also want to log the
    # dialog message
    if ($logfile && -f $logfile) {
        if (! open F, '>>', $logfile) {
            warn "Error opening log file $logfile: $!\n";
            return 0;
        }
        printf F "%s %-5.5d %s %-5.5s %s: %s\n", &timestamp, $$, $login, 
            $type, $app, $message;
        close F;
    }
    elsif ($S4P::rf_log_fn) {
        &{$S4P::rf_log_fn} (&timestamp, $$, $login, $type, $app, $message);
    }
    else {
        printf STDERR "%s %-5.5d %s %-5.5s %s: %s\n", &timestamp, $$, $login, 
            $type, $app, $message;
    }
    1;
}
#####################################################################
# redirect_log: routine used to redirect STDERR to the log file
#####################################################################
sub redirect_log {
    my ($redirect) = @_;
    if (ref $redirect) {
        $S4P::rf_log_fn = $redirect;
        return 1;
    }
    $S4P::rf_log_fn = undef;
    my $mode = (-e $redirect) ? ">>" : ">";
    if (! open F, "$mode $redirect") {
        printf STDERR "Error opening log file $redirect: $!\n";
        return 0;
    }
    *STDERR = *F;
    STDERR->autoflush(1);
    return 1;
}
sub raise_anomaly {
    my ($anomaly_type, $dir, $severity, $message, $mode) = @_;

    S4P::logger($severity, $message);
    # Get filename
    my $path = anomaly_path($anomaly_type, $dir);
    return 2 if ($mode == 2 && -f $path);

    # Open log file to append (creates if not there)
    if (!open (LOG, ($mode ? '>' : '>>'), $path)) {
        S4P::logger('ERROR', "Cannot open anomaly file $path: $!");
        return;
    }

    # Print message in log4perl format
    my @now = gmtime(time());
    printf LOG ("%04d/%02d/%02d %02d:%02d:%02d %s> %s\n", $now[5]+1900,
        $now[4]+1,$now[3], $now[2], $now[1], $now[0], $severity, $message);
    close LOG;
    return 1;
}
sub clear_anomaly {
    my ($anomaly_type, $dir) = @_;
    my $path = anomaly_path($anomaly_type, $dir);
    return unless (-f $path);
    if (unlink ($path)) {
       S4P::logger('INFO', "Cleared anomaly $anomaly_type");
       S4P::logger('INFO', "Cleared anomaly $anomaly_type", "$dir/station.log");
    }
    else {
       S4P::logger('ERROR', "Cannot clear anomaly $path: $!");
    }
}

sub anomaly_path{
    my ($type, $dir) = @_;
    return ($type =~ /^ANOMALY-.*\.log$/)   # Full filename supplied?
                       ? "$dir/$type"  
                       : sprintf("%s/ANOMALY-%s.log", $dir, $type);
}

#####################################################################
# job_message:  Write one-line message (up to 65 chars) to job.message 
#               file for display in tkstat.
#####################################################################
sub job_message {
    my $message = shift;
    # Replace spurious \n.
    $message =~ s/\n/ /gs;
    # Truncate to maxlen (currently 60) chars
    my $maxlen = 65;
    substr($message, $maxlen) = '' if (length($message) > $maxlen);
    if (!open MESSAGE, ">job.message" ) {
        S4P::logger('ERROR', "Cannot write to job.message file: $!");
        return;
    }
    print MESSAGE $message;
    close MESSAGE;
    return 1;
}
#####################################################################
# timestamp:  S4P-standard routine to format current time/date
#####################################################################
sub timestamp {
    return format_time(localtime);
}
sub format_time {
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $_[5]+1900, $_[4]+1,
                          $_[3], $_[2], $_[1], $_[0]);
}
sub format_localtime {
    my ($value) = @_;
    return format_time(localtime($value));
}
sub format_gmtime {
    my ($value) = @_;
    return format_time(gmtime($value));
}
sub unique_id {
    my $now = format_localtime(time());
    $now =~ s/[-:]//g;
    $now =~ s/ +/_/g;
    return ($now . '_' . $$);
}

######################################################################
# CONFIGURATION FILE OPERATIONS
######################################################################
# read_safe_config: use Safe module to read in config file.

sub read_safe_config {
    my ($file, $namespace) = @_;
    unless ($file) {
        S4P::logger('ERROR', "No file specified in read_safe_config");
        return;
    }
    $namespace ||= 'CFG';
    my $cpt = new Safe($namespace);
    if ($cpt->rdo($file)) {
        # Export environment variables
        set_config_env($namespace);
        return 1;
    }
    else {
        S4P::logger('ERROR', "Failed to read config file $file: $!");
        return;
    }
}
sub set_config_var {
    no strict 'refs';
    my ($obj, $name, $ns, $default) = @_;
    # Note that we expect the config variable to begin with "cfg_".
    # We set the attribute to be the same, minus the "cfg_" prefix.
    my $var = $ns . '::cfg_' . $name;
    if (defined($$var)) 
    { 
        $obj->{$name} = $$var; 
    }
    elsif (defined($default)) {
        $obj->{$name} = $default;
    }
}

sub set_config_env {
    no strict 'refs';
    my ($ns) = @_;
    my $var = $ns . '::ENV';
    while (my ($key, $val) = each(%$var)) {
        # Special case:  appending to PATH (and LD_LIBRARY_PATH) variables
        if ($key =~ /PATH$/ && $val =~ /^:/) {
            $ENV{$key} .= $val;
        }
        else {
            $ENV{$key} = $val;
        }
        S4P::logger('DEBUG', "Setting environment variable $key");
    }
}

    
 #read_config_file is deprecated. See read_safe_config.
# read_config_file:  convenience routine for reading configuration file
#=====================================================================
sub read_config_file {
    my $file = shift;
    my $calling_pkg = caller;   # Needed for "forcible" export into namespace

    my $pathname = find_config_file($file);
    return 0 if (! $pathname);

    # Open file
    if (! open(CONFIG, $pathname)) {
        S4P::logger 'FATAL', "Cannot open config file $pathname: $!";
        return 0;
    }
    # Loop through each line, evaling as we go...
    my $eval_string;
    while (<CONFIG>) {
        # Insert caller namespace AFTER the first character (which is $, @ or %)
        next if /^\s*#/;  # Ignore comment lines
        next if /^\s*$/;  # Ignore blank lines

        # Append to eval_string if we didn't already evaluate it
        if ($eval_string) {
            $eval_string .= ' ' . $_;
        }
        else {
            $eval_string = $_;
        }

        # If end of line is a semicolon, evaluate and re-initialize it
        if ($eval_string =~ /;\s*$/) {
            substr($eval_string,1,0) = "${calling_pkg}::";
            eval $eval_string;
            print $@;   # $EVAL_ERROR
            $eval_string = '';
        }
    }
    close CONFIG;
    return 1;
}
#####################################################################
# find_config_file:  look for configuration file in @INC
#=====================================================================
sub find_config_file {
    my ($filename) = @_;
    my ($realfilename);
    #check to see if the whole path was already sent before searching @INC
    return $filename if ( -f $filename); 
    my $prefix;
    foreach $prefix(@INC) {
        $realfilename = "$prefix/$filename";
        return $realfilename if (-f $realfilename);
    }
    # We only end up here if we failed to find it in the @INC path
    S4P::logger ('FATAL', 
           join (' ', "Cannot find config file $filename in " , @INC));
    return '';
}

#####################################################################
# F I L E   O P E R A T I O N S
#####################################################################
# read_file:  convenience routine for reading file into a string
#====================================================================
sub read_file {
    my $filename = shift;
    # Does file exist?
    if (! -e $filename) {
        S4P::logger 'ERROR', "File $filename does not exist";
        return 0;
    }
    # Open file
    if (! open INPUT, $filename) {
        S4P::logger 'ERROR', "Cannot open file $filename: $!";
        return 0;
    }
    my $save_input_record_separator = $/;
    undef $/;
    my $s = <INPUT>;           # Read the file (N.B.:  not space-efficient)
    $/ = $save_input_record_separator;
    close INPUT;
    return $s;
}

#####################################################################
# write_file:  convenience routine for writing a string to file
#====================================================================
sub write_file {
    my ($filename, $text) = @_;
    if (! open OUTPUT, ">$filename") {
        S4P::logger('ERROR', "Cannot open file $filename for writing: $!");
        return 0;
    }
    local($\)=undef;        # Unset the output record separator
    print OUTPUT $text;  # Remember, we shifted it up above
    close OUTPUT or S4P::logger('ERROR', "Cannot close $filename: $!");
    return 1;
}

#####################################################################
# perish:  S4P-standard routine for dying gracefully
#####################################################################
sub perish {
    my $exit_code = shift;
    my $string = shift;

    # Append the Exit code to the string passed in.
    # (All perishable strings are by definition FATAL)
    logger 'FATAL', $string . " (Exit=$exit_code)";
    exit($exit_code);
}

#####################################################################
# E X T E R N A L   S Y S T E M   C A L L S
#####################################################################
# exec_system:  convenience routine for executing system call and interpreting
#               return codes
#====================================================================
sub exec_system {

    # "localize" SIG{CHLD} to get around Sun problem of conflicting
    # signal handlers
    my $save_sig = $SIG{CHLD};
    undef($SIG{CHLD}) if $SIG{CHLD};
    my $rc = 0xffff & system( @_ );
    $SIG{CHLD} = $save_sig if ($save_sig);
    return translate_system_return($_[0], $rc, wantarray);
}
sub translate_system_return {
    my ($cmd, $rc, $wantarray) = @_;
    # Success
    if ($rc == 0) {
        return $wantarray ? ('',0) : 0;
    }
    # Command failed to execute
    elsif ($rc == 0xff00) {
        return $wantarray ? ("Command $cmd failed: $rc", $rc) : $rc;
    }
    # Command executed, but exited with a non-zero status
    elsif ($rc > 0x80) {
        $rc >>= 8;
        return $wantarray ? ("Job failed with exit $rc", $rc) : $rc;
    }
    # Command terminated abnormally (coredump or signal)
    else {
        if ($rc & 0x80) {
            $rc &= ~0x80;
            return $wantarray ? 
                ("Command $cmd died with coredump from signal $rc", $rc) : $rc;
        }
        else {
            return $wantarray ? ("Command $cmd died with signal $rc", $rc) : $rc;
        }
    }
}

#####################################################################
# fork_command:  convenience routine for forking a system call
#====================================================================
sub fork_command {
    my ($command, @args) = @_;
    my $n_tries = 0;
    return 0 if (! $command);
    if ($^O =~ /Win32/) {
        my $fullpath = $ENV{'SYSTEMROOT'} . '\\system32\\cmd.exe';
        my @cmd;
        my $cmdbase;
        $cmdbase = basename ($command);
        push (@cmd, '/C', $cmdbase, @args);
        my $proc;
        Win32::Process::Create($proc,
            $fullpath,                          # Command full path
            join(' ', @cmd),  # Command line for executable
            1,                                     # handle inheritance
            undef,
            "."                                    # Working directory
        );
        return 1;
    }
    FORK: {
        my $pid;
        # Parent case:  PID is non-zero
        if ($pid = fork()) {
            $SIG{CHLD} = sub {my $stiff; while ($stiff = waitpid(-1, &WNOHANG) > 0) {}};
            return 1;
        }
        # Child case:  PID is defined, but zero, so exec
        elsif (defined $pid) {
            exec($command, @args);
        }
        # EAGAIN, Supposedly recoverable fork error...
        elsif ($! =~ /No more process/ && $n_tries > 1000) {
            sleep 6;
            $n_tries++;
            redo FORK;
        }
        else {
            return 0;
        }
    }
}
#####################################################################
# nervous_system:  system-type call that keeps an eye out for the 
#   appearance of a signal file indicating that the subprocess should 
#   be suspended (SUSPEND_JOB_NOW), resumed (RESUME_JOB_NOW), or killed
#   (END_JOB_NOW).
#   NOTE:  kill(0, $pid) is used to wait for termination instead of
#   waitpid, because the latter seems to conflict with the zombie
#   reaping signal handler insofar as capturing the return code is
#   concerned.
#====================================================================
sub nervous_system {
    my ($stop_interval, $deadline, $command, @args) = @_;

    # stop_interval: how often we check for signal files
    # deadline:  the maximum time to run before we terminate the job
    
    my $n_tries = 0;
    my $kill_interval = 0.25;  # Frequency to check for child process
    my $t_total = 0;
    my $stop_file = "END_JOB_NOW";
    my $suspend_file = "SUSPEND_JOB_NOW";
    my $resume_file = "RESUME_JOB_NOW";
    FORK: {
        my $pid;
        my ($rc, $err_str);
        # Parent case:  PID is non-zero
        if ($pid = fork()) {
            # Install signal handler to reap zombies AND capture return code
            $SIG{CHLD} = sub {my $stiff; while ($stiff = waitpid(-1, &WNOHANG) > 0) {$rc=0xffff & $?} };
            S4P::logger('DEBUG', "Forked off child $pid: $command, stop_interval=$stop_interval");
            S4P::logger('DEBUG', "Job deadline=$deadline") if $deadline;
            my $t = 0;

            # $moribund is a flag so we don't keep checking for signal
            # files, just the existence of the child process
            my $moribund;

            # Loop through intervals at $kill_interval increments
            CHECK: while () {
                # If we have gone past $stop_interval, check for stop file
                # Check for READABILITY, not just existence
                if ($t > $stop_interval) {
                    # Is END_JOB_NOW there?  If so, terminate
                    if (-r $stop_file) {
                        S4P::logger('INFO', "$stop_file detected, sending kill to $pid");
                        if (terminate_job(getcwd())) {
                            unlink($stop_file) or 
                               S4P::logger('ERROR', "Failed to unlink signal file $stop_file: $!");
                            $moribund = 1;
                        }
                        else {
                            S4P::logger('ERROR', "Failed to terminate job $pid");
                        }
                    }
                    # Is SUSPEND_JOB_NOW there?  If so, SUSPEND
                    elsif (-r $suspend_file) {
                        S4P::logger('INFO', "$suspend_file detected, sending kill to $pid");
                        if (signal_job_child(getcwd(), 'STOP')) {
                            unlink($suspend_file) or 
                               S4P::logger('ERROR', "Failed to unlink signal file $suspend_file: $!");
                        }
                        else {
                            S4P::logger('ERROR', "Failed to suspend job $pid");
                        }
                    }
                    # Is RESUME_JOB_NOW there?  If so, RESUME
                    elsif (-r $resume_file) {
                        S4P::logger('INFO', "$resume_file detected, sending kill to $pid");
                        if (signal_job_child(getcwd(), 'CONT')) {
                            unlink($resume_file) or 
                               S4P::logger('ERROR', "Failed to unlink signal file $resume_file: $!");
                        }
                        else {
                            S4P::logger('ERROR', "Failed to suspend job $pid");
                        }
                    }
                    $t = 0;  # reset for $stop_interval check
                }
                # Check to see if job has exceeded maximum run time
                if ($deadline && $t_total > $deadline) {
                    S4P::logger('ERROR', "Job exceeded deadline of $deadline secs, sending kill to $pid");
                    S4P::logger('ERROR', "Failed to terminate job $pid")
                        unless ( terminate_job(getcwd()) );
                    $moribund = 1;
                }
                # Jump out if the job is dead
                last CHECK unless (kill(0, $pid));

                # $moribund means we sent the kill signal.  Now wait until 
                # it's *really* dead, i.e. caught by SIG{CHLD} handler
                if ($moribund) {
                    while (kill(0, $pid)) {
                        select undef, undef, undef, $kill_interval
                    }
                    last CHECK;
                }

                # Sleep for a short interval
                select undef, undef, undef, $kill_interval;
                $t += $kill_interval;
                $t_total += $kill_interval;
            }
            return translate_system_return($command, $rc, wantarray);
        }
        # Child case:  PID is defined, but zero, so exec
        elsif (defined $pid) {
            exec($command, @args);
        }
        # EAGAIN, Supposedly recoverable fork error...
        elsif ($! =~ /No more process/ && $n_tries > 100) {
            sleep 6;
            $n_tries++;
            redo FORK;
        }
        else {
            return 0;
        }
    }
}
#####################################################################
# COUNTER LOG ROUTINES
#####################################################################
# open_counter:  S4P-standard routine for opening a "counter" file
#====================================================================
sub open_counter {
    my ($file) = @_;
    my $mode = (-e $file) ? ">>" : ">";
    if (! open COUNTER, "$mode $file") {
        printf STDERR "Error opening counter file $file: $!\n";
        return 0;
    }
    COUNTER->autoflush(1);
    return 1;
}
#####################################################################
# counter:  S4P-standard routine for writing to a "counter" file
#====================================================================
sub counter {
    my ($message) = @_;
    my $app = $0;
    $app =~ s#.*/##;
    printf COUNTER "%s %-5.5d %-5.5s %s: %s\n", &timestamp, $$, "INFO", $app, 
                   $message . " EPOCH=" . time();
    1;
}
############################################################################
# STATION STATUS ROUTINES
############################################################################
# Backward compatibility only
sub check_daemon {
    check_station(@_);
}
sub check_station {
    my $directory = shift || '.';
    my $file = sprintf("%s/station.lock", $directory);
    return 0 if (! -e $file);
    open (FH, $file) or return 0;
    # Being refused a file lock means there's a daemon running there.
    my $station_up = ! flock(FH, 1 | 4);
    close FH;
    # N.B.:  Experimental feature!
    # File locking over NFS doesn't always work, so try again, but
    # this time with an exclusive write-lock
    if (! $station_up && ($^O eq 'linux') && $ENV{'S4P_LINUX_LOCK'}) {
        # Use append so we don't truncate/overwrite anything by accident...
        open (FH, ">>$file") or exit 0;
        $station_up = ! flock(FH, 1 | 2);
        close FH;
    }

    return $station_up ? 1 : 0;
}
#####################################################################
# Job Control Routines
#     parse_job_type - parse job type, job_id, etc. from filename
#     check_job - get information on job (pid, owner, status) from job.status
#     write_job_status - write job.status file
#     end_job - end job's child
#     terminate_job - kill job's child
#     suspend_job - send SIGSTOP to job
#     resume_job - send SIGCONT to job
#####################################################################
# parse_job_type - parse job type, job_id, etc. from filename
#####################################################################
sub parse_job_type {
    my ($filename, $pattern) = @_;
    my $job_id = $filename;
    my $rerun = ($job_id =~ /^REDO/);

    # Skim off a priority prefix, if it exists, and save it.
    $job_id =~ s/^(PRI\w\.)//;
    my $priority = $1;

    # Determine the job_id and the job_type
    $job_id =~ s/^(RUNNING|FAILED|REDO|DO)\.//;
    my @parts = split('\.', $job_id);
    # If it's a normal work order name, pop the suffix; otherwise leave it
    pop @parts unless $pattern;
    $job_id = join('.', @parts);
    my $job_type = $job_id;
    $job_type =~ s/\..*//;
    return ($job_type, $job_id, $priority, $rerun);
}

#####################################################################
# check_job - look in job.status file for information about the 
#     currently running process:  
#     Line 1:  process_id owner status [status info]
#     Line 2:  comment
#####################################################################
sub check_job {
    my $directory = shift || '.';
    my $check_pid = shift;
    my $file = sprintf("%s/job.status", $directory);

    # Check to see if job.status file is really there
    if (! -e $file) {
        printf STDERR "S4P::check_job error: $file does not exist.\n";
        return;
    }
    # Open job status file for reading
    if (!open (FH, $file)) {
        printf STDERR "S4P::check_job error: cannot open $file: $!\n";
        return;
    }
    # Line 1:  pid, owner, status, extra info
    my $line = <FH>;
    chomp($line);
    my ($pid, $owner, $status, $status_info) = split / /, $line;
    if ($check_pid && $status eq 'RUNNING') {
        $status = 'DEFUNCT' unless check_pid($pid);
    }
    
    # Line 2:  original work order name (used for job restart)
    my $original_work_order = <FH>;
    chomp($original_work_order);

    # Third line is a "comment", usually the command.
    # TO DO:  read multiple lines
    my ($comment) = <FH>;
    chomp($comment);
    S4P::logger('ERROR', "Cannot close job.status file: $!") unless close(FH);
    return ($status, $pid, $owner, $original_work_order, $comment);
}
sub job_is_defunct {
    my $directory = shift;
    my ($status) = check_job($directory, 1);
    return ($status eq 'DEFUNCT');
}
sub end_job {
    my ($dir) = @_;
    alert_job($dir, 'END');
}
###########################################################################
# alert_job - drop a <signal_type>_JOB_NOW signal file, which will cause 
#     stationmaster to call the corresponding function or call the function
#     directly.  The former is used if the station.cfg for
#     the station as $cfg_end_job_interval set.
#==========================================================================
sub alert_job {
    my ($dir, $signal_type) = @_;


    my %kill_fns = ('END' => \&terminate_job,
        'SUSPEND' => \&suspend_job_child,
        'RESUME' => \&resume_job_child,
    );
    my $kill_fn = $kill_fns{$signal_type};
    unless ($kill_fn) {
        S4P::logger('ERROR', "Unrecognized signal type $signal_type");
        return 0;
    }
    
    # Read station.cfg in the parent directory to see 
    # if $cfg_end_job_interval is set
    my $station_config = "../station.cfg";
    my $cpt = Safe->new("STATION");

    # If we have trouble reading it, (gone maybe?), try to kill the job anyway;
    # maybe the problems are related.
    unless (-f $station_config) {
        S4P::logger('ERROR', "No station.cfg found, calling function directly");
        return &$kill_fn($dir);
    }
    unless ($cpt->rdo($station_config)) {
        S4P::logger('ERROR', "Cannot read/do station.cfg file, calling terminate_job()");
        return &$kill_fn($dir);
    }
    # Call terminate_job() right off if cfg_end_job_interval is not set
    unless ($STATION::cfg_end_job_interval) {
        return &$kill_fn($dir);
    }
    # If cfg_end_job_interval is set, just write the file that signals
    # stationmaster to call terminate_job().  This allows a different user
    # to terminate it.
    my $signal_file = sprintf("%s_JOB_NOW", $signal_type);
    unless (write_file($signal_file, "$signal_type job now")) {
        S4P::logger('ERROR', "Cannot write to $signal_file: $!");
        return 0;
    }
    return 1;
}
sub terminate_job {
    my ($dir) = @_;
    signal_job_child($dir, ($ENV{'S4P_KILL_TERM'} ? 'TERM' : 9) );
}
sub init_sig_num {
    return if $S4P::sig_num{'TERM'};
    use Config;
    my @names = split ' ', $Config{sig_name};
    @S4P::sig_num{@names} = split ' ', $Config{sig_num};
}

#####################################################################
# signal_job_child - send a kill signal to the child of the forked
#     stationmaster job.
#     Note:  we kill the children (the command being run) so that the forked
#     stationmaster can detect it and log as such.  If we killed the
#     forked stationmaster process, we would have no trace in the log
#     N.B:  this works only for processes run as separate commands, not
#     those run as Perl modules.
#     TO DO:  handle jobs that are run as Perl modules
#====================================================================
sub suspend_job_child {
    my $dir = shift;
    write_file("$dir/SUSPEND", localtime());
    return signal_job_child($dir, 'STOP');
}
sub resume_job_child {
    my $dir = shift;
    my $rc = signal_job_child($dir, 'CONT');
    unlink "$dir/SUSPEND" if ($rc && -e "$dir/SUSPEND");
    return $rc;
}
sub signal_job_child {
    my ($dir, $signal) = @_;
    my ($status, $pid, $owner, $orig_wo, $comment) = check_job($dir);
    return 0 if (! $status);

    # Get all descendents of PID
    my @pids = pidtree($pid);

    # No Descendants found, rename to FAILED.
    unless (@pids) {
        my $failed_dir = $dir;
        $failed_dir =~ s/RUNNING/FAILED/;
        if (! rename($dir, $failed_dir)) {
            S4P::logger('ERROR', "Failed to rename $dir to $failed_dir: $!");
            return 0;
        }
        return 1;
    } 

    my @err;
    foreach my $pid(@pids) {
        my $rc = kill $signal, $pid;
        push @err, $pid unless $rc;
    }
    if (@err) {
        S4P::logger('ERROR', "Failed to send signal $signal to children " . join(', ', @err));
    }
    if ($signal eq 'STOP') {
        update_job_status ($dir, 'SUSPENDED');
    }
    elsif (!@err && $signal eq 'CONT') {
        update_job_status ($dir, 'RUNNING');
    }
    return 1;
}
# check_pid($pid) 
# Check to see whether a certain process_id is still active
sub check_pid {
    my $pid = shift;
    my $cmd = "ps -o pid -p $pid";
    # First line is always the header; strip it
    my @results = grep !/PID/, `$cmd`;
    # Any lines left?  If so, still running...
    return scalar(@results);
}
    
sub pidtree {
    my $root_pid = shift;
    my %pids;
    # Run ps and capture output
    unless (open (PS, "ps -o pid,ppid|")) {
        warn("Cannot open pipe to ps command");
        return;
    }
    my $hdr = <PS>;
    # Save as associative arrays hashed on parent process_id
    while (<PS>) {
        s/^\s*//;
        my ($pid, $ppid, $command) = split;
        push @{$pids{$ppid}}, $pid;
    }
    close PS;

    # Using hash, start at the requested pid and work downward, breadth first
    # The "tree" structure is not so important as getting all the descendants
    my @pstree = ();
    my @check = ($root_pid);
    while (1) {
        my $n_found;
        my @children;
        foreach my $pid(@check) {
            push @children, @{$pids{$pid}} if (exists $pids{$pid});
        }
        push @pstree, @children;
        @check = @children;
        last unless @children;
    }
    return @pstree;
}

sub suspend_job { signal_job('STOP', 'SUSPENDED', @_) };
sub resume_job { signal_job('CONT', 'RUNNING', @_) };
sub signal_job {
    my ($signal, $new_status, $dir) = @_;
    my ($status, $pid, $owner, $orig_wo, $comment) = check_job($dir);

    # Return if we couldn't get a job status
    return 0 if (! $status);

    # Check to see if we're beating a dead horse
    if ($status eq $new_status) {
        print STDERR "Job in $dir is already $new_status\n";
        return 0;
    }

    # OK, now send the signal
    my $rc = kill ($signal, $pid);
    if (! $rc) {
        print STDERR "Could not send signal $signal to process $pid\n";
        return 0;
    }
    update_job_status($dir, $new_status);
}
##########################################################################
# fail_job($job_id, $error_message, $exit_code, $token):
#      rename job directory and write to log
##########################################################################
sub fail_job {
    my ($job_id, $message, $exit_code, $case_log, $rename_retries, 
        $rename_retry_interval, $token) = @_;
    my ($job_type) = split('\.', $job_id);
    # Update counter log
    S4P::counter("FAILED $job_type");
    # Update case-based reasoning log
    if ($case_log) {
        S4P::log_case($case_log, 'F', $exit_code, "Job Failed");
    }
    # Go up to parent directory
    if (! chdir '..') {
        S4P::logger('ERROR', "Failed to cd to ..: $!");
        return;
    }
    my @dir;
    my $pid = abs($$);
    # Rename directory from RUNNING to FAILED
    my $fail_dir;
    if (-d "RUNNING.$job_id") {
        $fail_dir = "FAILED.$job_id.$pid";
        S4P::logger('INFO', "Renaming failed job directory to $fail_dir");
        S4P::rename_job_dir("RUNNING.$job_id", $fail_dir, $rename_retries,
           $rename_retry_interval);
    }
    elsif (@dir = glob("RUNNING.PRI?.$job_id")) {
        $fail_dir = "$dir[0].$pid";
        $fail_dir =~ s/RUNNING/FAILED/;
        S4P::rename_job_dir($dir[0], $fail_dir, $rename_retries, $rename_retry_interval);
    }
    unless ($message) {
        my ($pkg, $fname, $line) = caller();
        $message = "$fname, $pkg at line $line";
    }
    S4P::logger("FATAL", $message);
    S4P::release_token($token) if $token;
    return $fail_dir;
}
##########################################################################
# rename_job_dir($old, $new, $retries, $retry_interval):
#   rename failed work order directory
#   Since Windows has some quirks, we allow for the possibility of the
#   rename failing
##########################################################################
sub rename_job_dir {
    my ($old, $new, $retries, $retry_interval) = @_;
    my $count = 0;
    $retries = 0 unless (defined($retries));
    until ($count > $retries) {
        if (!rename($old, $new)) {
            $count++;
            S4P::logger('ERROR', "failed to rename $old to $new (try $count): $!");
        }
        else {
            return 1;
        }
        sleep($retry_interval);
    }
    S4P::logger('ERROR', "failed to rename $old to $new after $count tries, giving up");
    return 0;
}
sub restart_job{
    my $dir = cwd();
    return 0 if (still_running($dir));
    my $file;
    my ($status, $pid, $owner, $orig_wo, $comment) = check_job($dir);

    if (! $status) {
        S4P::logger('ERROR', "Could not get get status from job.status file");
        return;
    }

    # Copy log file(s) up one directory
    my @log = glob('*.log');
    foreach my $file(@log) {
        if (! copy($file, '..')) {
            S4P::logger('ERROR', "Cannot copy $file to ..: $!");
            return;
        }
    }

    # Open directory for reading
    opendir (DIR, $dir);
    while (defined($file = readdir(DIR))) {
        if ($file =~ /^DO\./) {
            # Move work order up one directory
            if (! rename($file, "../$orig_wo")) {
                S4P::logger('ERROR', "Failed to move work order $file to ../$orig_wo");
                return 0;
            }
        }
    }
    closedir (DIR);
    return $orig_wo;
}
#===========================================================================
# restart_defunct_jobs
#   From current station directory, examine all RUNNING.* directories to
#   see if the process_ids therein are still active.
#   For each one that is NOT, fail the job, restart it, and then remove the
#   old one.
#---------------------------------------------------------------------------
sub restart_defunct_jobs {
    my ($case_log, $rename_retries, $rename_retry_interval) = @_;

    # Look for currently running jobs in current directory.
    my @running_jobs = glob('RUNNING.*');
    my @defunct_jobs;

    # Look for defunct jobs among
    my $n_restart;
    my $cwd = getcwd();
    foreach my $job_dir(@running_jobs) {
        next unless S4P::job_is_defunct($job_dir);
        if (!chdir($job_dir)) {
            S4P::logger('ERROR', "Failed to chdir to defunct job dir $job_dir: $!");
            next;
        }
        my $job_id = $job_dir;
        $job_id =~ s/^RUNNING\.//;
        $job_id =~ s/^PRI\d*\.//;
        my $fail_dir = S4P::fail_job($job_id, "Job $job_id is defunct", 253, 0);
        if (!chdir($fail_dir)) {
            S4P::logger('ERROR', "Failed to chdir to FAILED dir $fail_dir: $!");
        }
        elsif (! S4P::restart_job()) {
            S4P::logger('ERROR', "Failed to restart job $fail_dir: $!");
        }
        elsif (! S4P::remove_job()) {
            S4P::logger('ERROR', "Failed to remove job $fail_dir after restarting: $!");
        }
        elsif (! chdir($cwd)) {
            S4P::perish(26, "Failed to chdir back to station after restarting failed job $fail_dir");
        }
        else {
            # Successful restart leaves you in restart dir
            $n_restart++;
            S4P::logger('INFO', "Restarted defunct job dir $job_dir");
        }
    }
    return $n_restart;
}

sub remove_job{
    my $force = shift;
    my $curdir = cwd();

    # Just to be safe...
    if (still_running($curdir) && ! $force) {
        S4P::logger('ERROR', "Job appears to be still running in $curdir");
        return 0;
    }

    # Even if it's forced, check to see if we're in a station directory by mistake
    if (-f 'station.cfg') {
        S4P::logger('ERROR', "Found station.cfg in this directory; will not remove");
        return;
    }

    # Remove all files 
    if (! opendir DIR, '.') {
        S4P::logger('ERROR', "Could not open current directory $curdir");
        return;
    }
    my $file;
    while (defined($file = readdir(DIR))) {
        next if ($file eq '.' or $file eq '..');
        if (! unlink $file) {
            S4P::logger('ERROR', "Could not unlink file $file: $!");
            return;
        }
    }
    if (! chdir '..') {
        S4P::logger('ERROR', "Could not chdir to parent of $curdir: $!");
        return;
    }
    if (! rmdir($curdir)) {
        S4P::logger('ERROR', "Could not remove current directory $curdir");
        return;
    }
    return 1;
}
sub still_running {
    my $dir = shift;
    # Definitely dead if directory matches failed job pattern
    return 0 if (basename($dir) =~ /$S4P::failed_job_pattern/);

    # Otherwise, check job status file; sometimes RUNNING directories are
    # really no longer running
    my ($status, $pid, $owner, $orig_wo, $comment) = check_job($dir);
    return (defined($status) && $status !~ /FAIL/i);
}
##########################################################################
# update_job_status():  update status in job.status file to new value
#=========================================================================
sub update_job_status {
    my ($dir, $status) = @_;
    my ($old_status, $pid, $owner, $orig_wo, $comment) = check_job($dir) 
        or return 0;
    write_job_status($dir, $status, $orig_wo, $comment, $owner, $pid);
}
    
##########################################################################
# write_job_status():  write to job status file in RUNNING directory.
#=========================================================================
sub write_job_status {
    my ($dir, $status, $orig_wo, $comment, $username, $pid) = @_;

    # If directory is blank, get the current directory
    $dir ||= cwd();

    # Form full pathname
    my $file = "$dir/job.status";

    # Open job.status file for writing
    if (! open STATUS, ">$file") {
        S4P::logger("WARN", "Cannot create job status file $file: $!");
        return 0;
    }
    # If username is not specified, get it from the owner of the directory
    if (! $username) {
        my ($dev, $ino, $mode, $nlink, $uid, @stuff) = stat($dir);
        $username = ($^O =~ /Win32/i) ? $uid : getpwuid($uid);
    }
    # If process id is not specified, use this one
    $pid ||= $$;

    # Write contents to file and close up
    printf STATUS "%d %s %s\n", $pid, $username, $status;
    print STATUS "$orig_wo\n";
    print STATUS "$comment\n" if $comment;
    close STATUS or S4P::logger('ERROR', "Cannot close job.status file");
    return 1;
}
###########################################################################
# stop_station - stop stationmaster station by 
# (a) dropping a DO.STOP.NOW.wo work order, if $gently arg is specified
# (b) if not gently, extracting process_id from the station.pid file 
#     (if it exists) or the station.lock file and killing it.   
#     N.B.: This works only when you started that station.
#==========================================================================
sub stop_station {
    my ($option) = shift;
    return stop_station_dir('.', $option);
}
sub stop_station_dir {
    my $dir = shift;

    # Check to see if station is already down (can happen with Stop All)
    return unless check_station($dir);

    # Options are 'gently' and 'restart'; both use a work order
    my $option = shift;
    if ($option eq 'gently' || $option eq 'restart') {
        # Set job type for work order
        my $jobtype = ($option eq 'gently') ? 'STOP' : 'RESTART';
        my $stop_file = "$dir/DO.$jobtype.NOW.wo";

        # Open work order to write
        if ((! -f $stop_file) && (!open OUT, ">$stop_file")) {
            S4P::logger("ERROR", "Cannot write $stop_file: $!");
            return;
        }

        # Print process id to work order
        print OUT "$$\n";
        close OUT;
    }
    # Hard stop using kill
    else {
        # First try to get PID from station.pid, then try station.lock
        my $pid_file = (-f "$dir/station.pid") ? "$dir/station.pid" : "$dir/station.lock";
        if (! open(FH, $pid_file)) {
            return 0;
        }
        # Read the PID or lock file
        local($/) = undef;
        my $string = <FH>;
        close(FH);

        # Parse for PID
        if ($string =~ /pid=(\d+)/) {
            my $pid = $1;
            # Send SIGSTOP signal
            return kill(9, $pid);
        }
        else {
            return 0;
        }
    }
}

sub LOCK_EX () {2};
sub LOCK_NB () {4};

###########################################################################
# snore($sleep, $message)
#   $sleep - how many seconds to sleep
#   $message - message to write before going to sleep
# -------------------------------------------------------------------------
# snore is just like sleep, except it writes a little file with a message
# saying it is going to sleep and why.
#==========================================================================
sub snore {
    my ($sleep, $message) = @_;
    my $file = "sleep.message.$$";
    write_file($file, "Sleeping $sleep secs: $message\n");
    sleep($sleep);
    unlink($file);
}

###########################################################################
# await ($how_long, $interval, $message, \&check_function, $check_arg, ...)
#==========================================================================

sub await {
    use strict;
    my $how_long = shift;
    my $interval = shift;
    my $message = shift;
    my $rs_check_function = shift;
    my $timer = 0;
    # Check right away
    my $rc = &$rs_check_function(@_);
    return $rc if $rc;

    S4P::logger('INFO', $message . "; Will poll for $how_long sec at $interval sec intervals...");
    # Loop until we get a positive return or run out of time
    while (!$rc && $timer < $how_long) {
        $timer += $interval;
        snore($interval, $message . "\n$timer of $how_long sec elapsed");
        $rc = &$rs_check_function(@_);
    }
    S4P::logger('INFO', "$message; " . ($rc ? "No result" : "Result obtained") 
        . "after $timer secs");
    return $rc;
}
#############################################################################
# send_downstream($logfile, $rh_downstream, $priority, $root, $suffix) 
#   $logfile - cumulative logfile to be sent downstream
#   $rh_downstream - pointer to a hash of downstream stations keyed on job type
#   $priority - optional priority prefix for work order file name
#----------------------------------------------------------------------------
#   Send the output work order to the downstream stations
#============================================================================
sub send_downstream {
    # Require used here to avoid KGlob warnings in Perl 5.6
    require 5.6.0;
    my ($logfile, $rh_downstream, $priority, $root, $suffix) = @_;
    my %downstream = %{$rh_downstream};
    my $i;  # Loop iterator
    my $job_type;
    my @output_work_orders;
    my $n_errs = 0;
    foreach $job_type (keys %downstream) {
       # Downstream stations are in  an anonymous list
       my $ra = $downstream{$job_type};
       my (@destdirs, $destdir, $file);
       my @a;

       # Prepend root to destination directories if no leading slash
       if ($root) {
           @a = @{$ra};
           for ($i = 0; $i < scalar @a; $i++) {
               $destdirs[$i] = ($a[$i] =~ m#^(/|[a-z]+://)#) 
                                ? $a[$i] : "$root/$a[$i]";
           }
       }
       else {
           @destdirs = @{$ra};
       }
       S4P::logger("DEBUG", "Destinations for work orders of type $job_type: " 
                             . join(' ', @destdirs));
       # Set suffix if not specified
       $suffix ||= $S4P::work_order_suffix;
       S4P::logger("DEBUG", "Using work order suffix $suffix");
       @output_work_orders = glob("$job_type.*.$suffix");
       if (scalar(@output_work_orders) == 0) {
           S4P::logger("DEBUG",
                       "No output work orders of type $job_type created");
       }
       # Loop through all work orders for this downstream job type
       foreach $file (@output_work_orders) {
           S4P::logger("DEBUG", "Moving output work order $file downstream");
           # Loop through the list of downstream destinations
           foreach $destdir(@destdirs) {
               # Prepend root if it exists
               my $destination = "$destdir/$priority" . "DO.$file";
               S4P::logger("DEBUG", "Copying work order $file to $destination");

               if (! S4P::move_file($file, $destination) ) {
                   S4P::logger("ERROR", 
                    "Cannot copy work order $file to $destination");
                   $n_errs++;
               }
               # We check the special case of the log file being the same as
               # the work order. This is used by "deadend" stations to archive
               # logs to a directory.  In this case, the log file will be moved
               # only once, as a "work order", not as a "log file"
               elsif ($file ne $logfile) {
                   $destination = "$destdir/$file";
                   # parse for the suffix and replace with .log
                   # First case: glob wildcards
                   # Lop off the last part and replace it with log
                   if ($suffix =~ /[\{\(\|\*\?]/) {
                       my @parts = split('\.', $file);
                       if (scalar(@parts) > 1) {
                           $destination =~ s/\.$parts[-1]$/.log/;
                       }
                       # No extensions at all:  go ahead and add .log to the end
                       else {
                           $destination .= '.log';
                       }
                   }
                   # Second case: simple suffix (no glob wildcards)
                   else {
                       $destination =~ s/\.$suffix$/.log/;
                   }
                   S4P::logger("DEBUG", "Copying log $logfile to $destination");
                   if (! S4P::move_file($logfile, $destination)) {
                       S4P::logger("ERROR", 
                        "Cannot copy log file $logfile to $destination");
                       $n_errs++;
                   }
               }
           }
           if ($n_errs == 0) {
               S4P::logger("DEBUG", 
                        "Log & work order moved: unlinking $file");
               unlink($file);
           }
       }
    }
    return ($n_errs == 0);
}

sub log_case {
    my ($file, $type, $exit_code, $info, $station, $job_type, $job_id) = @_;
    return unless ($file);

    # Case timestamp (epochal)
    my $now = time();

    # Get station, job_type, job_id if not specified
    unless ($station) {
        my $cwd = cwd();
        my $base = basename($cwd);

        # If this is being done from within a job directory...
        if ($base =~ /^(RUNNING|FAILED)\.(.*?)\.(.*?)/) {
            $job_type = $2;
            $job_id = $3;
            $station = basename(dirname($cwd));
        }
        # Manual actions may take place at the station level
        else {
            $station = $base;
        }
    }

    # Open Case log file
    if (! open CASE, ">> $file") {
        S4P::logger('ERROR', "Cannot open case log $file to append: $!");
        return;
    }

    # Write to Case log file
    printf CASE "%d %s %3d %s %s %s \"%s\"\n", $now, $type, $exit_code, $station,
        $job_type, $job_id, $info;

    # Close file
    close CASE;
    return 1;
}

sub authenticate_unix_user {

    my ($username, $password) = @_;

    my @pwstruct = CORE::getpwnam($username);
    return 0 if ( scalar(@pwstruct) == 0 );

    my $salt = substr $pwstruct[1], 0, 2;

    if (crypt($password, $salt) eq $pwstruct[1]) {
        return 1;
    } else {
        return 0;
    }
}

sub criteria_value {

    my $tree = shift;
    my $name = shift;

    my @nodes = $tree->search(NAME => 'SPECIALIZED_CRITERIA');
    unless ( @nodes ) { return undef; }
    foreach my $node ( @nodes ) {
        my $n = $node->getAttribute('CRITERIA_NAME');
        $n =~ s/"//g;
        if ( $n eq $name ) {
            my $v = $node->getAttribute('CRITERIA_VALUE');
            $v =~ s/"//g;
            return $v;
        }
    }
    return undef;
}

sub criteria_type {

    my $tree = shift;
    my $name = shift;

    my @nodes = $tree->search(NAME => 'SPECIALIZED_CRITERIA');
    unless ( @nodes ) { return undef; }
    foreach my $node ( @nodes ) {
        my $n = $node->getAttribute('CRITERIA_NAME');
        $n =~ s/"//g;
        if ( $n eq $name ) {
            my $v = $node->getAttribute('CRITERIA_TYPE');
            $v =~ s/"//g;
            return $v;
        }
    }
    return undef;
}

sub criteria_names {

    my $tree = shift;
    my @names = ();

    my @nodes = $tree->search(NAME => 'SPECIALIZED_CRITERIA');
    unless ( @nodes ) { return undef; }
    foreach my $node ( @nodes ) {
        my $n = $node->getAttribute('CRITERIA_NAME');
        $n =~ s/"//g;
        push(@names, $n);
    }

    return @names;
}

sub criteria_hash {

    my $tree = shift;

    my %criteria_hash = ();

    my @LineItemSetList = $tree->search(NAME => 'LINE_ITEM_SET');
    my $n_sets = scalar(@LineItemSetList);

    if ( $n_sets > 0 ) {
        foreach my $LineItemSet ( @LineItemSetList ) {
            my @LineItemList = $LineItemSet->search( NAME => 'LINE_ITEM' );
            foreach my $LineItem ( @LineItemList ) {
                my @SpecializedCriteriaList = $LineItem->search( NAME => 'SPECIALIZED_CRITERIA');
                my $PackageID = $LineItem->getAttribute('PACKAGE_ID');
                $PackageID =~ s/"//g;
                my @package_tokens = split(/:/, $PackageID);
                my $esdt = $package_tokens[1];
                foreach my $SpecializedCriteria ( @SpecializedCriteriaList ) {
                    my $name  = $SpecializedCriteria->getAttribute('CRITERIA_NAME');
                    my $value = $SpecializedCriteria->getAttribute('CRITERIA_VALUE');
                    $name =~ s/"//g;
                    $value =~ s/"//g;
                    $criteria_hash{"$name|$esdt"} = $value;
                }
            }
        }
    } else {
        my @LineItemList = $tree->search(NAME => 'LINE_ITEM');
        foreach my $LineItem ( @LineItemList ) {
            my @SpecializedCriteriaList = $LineItem->search( NAME => 'SPECIALIZED_CRITERIA');
            my $PackageID = $LineItem->getAttribute('PACKAGE_ID');
            $PackageID =~ s/"//g;
            my @package_tokens = split(/:/, $PackageID);
            my $esdt = $package_tokens[1];
            foreach my $SpecializedCriteria ( @SpecializedCriteriaList ) {
                my $name  = $SpecializedCriteria->getAttribute('CRITERIA_NAME');
                my $value = $SpecializedCriteria->getAttribute('CRITERIA_VALUE');
                $name =~ s/"//g;
                $value =~ s/"//g;
                $criteria_hash{"$name|$esdt"} = $value;
            }
        }
    }
    
    return(%criteria_hash);

}

# get_ftp_login($host) - retrieve FTP login, password from .netrc file
sub get_ftp_login {
    my ($host) = @_;
    if (!open IN, "$ENV{'HOME'}/.netrc") {
        warn "Cannot open .netrc file";
        return 0;
    }
    while (<IN>) {
        my %hash = split;
        return ($hash{'login'}, $hash{'password'}) if ($hash{'machine'} eq $host);
    }
    warn "WARNING: Cannot find info for machine $host in .netrc";
    return;
}
################################################################
# Token handling:  
#    Request a run token:  Write a work order DO.TOKEN.$id.wo 
#        to the tokenmaster directory and wait for a file named 
#        GRANTED.$id to show up
#    Release a run token:  When job is finished or failed,
#        unlink the GRANTED.$id file
################################################################
sub request_token {
    use strict;
    my ($token_dir, $jobpath, $job_type_and_id, $wait, $interval) = @_;

    # Wait/interval defaults
    $wait ||= 3600*24;
    $interval ||= 5;

    # Uniqueness:  
    #   For one stationmaster, should have only one job_type and one job_id.   
    #   Then we compute a checksum for the station directory to further 
    #   guarantee uniqueness.
    my $station_id = unpack('%C32', dirname($jobpath));
    my $id = join('.', $job_type_and_id, $station_id);
    my $token_file = "$token_dir/DO.TOKEN.$id.wo";
    my $grant_file = "GRANTED.$id.tkn";
    my $grant_path = "$token_dir/$grant_file";

    # Open token work order for writing
    if ( !open(TOKEN, ">$token_file") ) {
        S4P::logger('ERROR', "Failed to open token file $token_file: $!");
        return undef;
    }
    print TOKEN "$grant_file\n";
    print TOKEN "$jobpath\n";
    close TOKEN;
    S4P::logger('DEBUG', "Wrote to $token_file");

    # Now check for token granting
    if (S4P::await ($wait, $interval, 'Waiting for run token', sub {return (-f $grant_path)})) {
       return Cwd::abs_path($grant_path);
    }
    else {
       return undef;
    }
}
sub grant_token {
    my $work_order = shift;

    # Read grant_file from work order
    # (More reliable than parsing work order name)
    open (WORK, $work_order) or 
        S4P::perish(23, "Failed to open work order $work_order");
    my $grant_file = <WORK>;
    close(WORK);
    chomp($grant_file);

    # Move to GRANTED status
    my $grant_path = "../$grant_file";
    if (! copy($work_order, $grant_path)) {
       S4P::logger('ERROR', "Failed to copy $work_order to $grant_path: $!");
       return undef;
    }
    return $grant_path;
}

sub release_token {
    my $file = shift;
    # Just in case token may have been "manually" released
    if (! -f $file) {
        S4P::logger('WARN', "Token file $file appears to have been removed already");
        return 2;
    }
    if (!unlink($file)){
        S4P::logger('ERROR', "Failed to remove token file $file: $!");
        return 0;
    }
    else {
        S4P::logger('DEBUG', "Removed token file $file");
    }
    return 1;
}
#======================================================================
# http_get
#----------------------------------------------------------------------
sub http_get {
    my ($url, $user, $password) = @_;

    # require instead of use, so that we don't force institutions to
    # install these libraries if they don't need HTTP transfer.
    require LWP::UserAgent;
    require HTTP::Request;
    require HTTP::Response;

    my $user_agent = new LWP::UserAgent('agent'=>'S4P/5.20');;
    my $request = HTTP::Request->new(GET => $url);
    $request->authorization_basic($user, $password); 
    my $response = $user_agent->request($request);
    if ($response->is_error()) {
        S4P::logger('ERROR', 
            "Failed to get URL $url: " . $response->status_line);
        return;
    }
    return $response->content();
}
