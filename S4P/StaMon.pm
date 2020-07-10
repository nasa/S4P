=head1 NAME

StaMon - station monitor object, used by tkstat

=head1 SYNOPSYS

use S4P::StaMon;

my $stamon = S4P::StaMon::create($station, $start_time);

$stamon->refresh;

my $n_jobs = $stamon->n_jobs;

my $n_run = $stamon->n_run;

my $n_pend = $stamon->n_pend;

my $n_suspend = $stamon->n_suspend;

my $n_fail_jobs = $stamon->n_fail_jobs;

my $n_fail_work_orders = $stamon->n_fail_work_orders;

my $jobdir = $stamon->jobs($i);

my $status = $stamon->status($i);

my $num_successes = $stamon->success_count;

my $num_failures = $stamon->failuser_count;

=head1 DESCRIPTION

The StaMon object is basically a structure for monitoring stations, with
two simple methods.

The create() method creates the structure for a given station[:job_type].
It returns a new S4P::StaMon object after reading the station.cfg file and
filling in all of the attributes it can from that.

The refresh() method looks for running, failed and pending jobs in the
station and puts then into a single I<unsorted> array, B<jobs>.
It also places the status of each job in a parallel array, B<status>.
The statuses are indicated by letter codes to support sorting:

  a = failed work order
  b = failed job
  c = warning (late) job
  d = suspended job
  e = running job
  f = pending job

It takes a parameter hash, where the parameter(s) are as follows:
  -skip_counters:  skips the update of the counter (which can take a long time
                   at startup).

=head1 FILES

StaMon reads the B<station.cfg> file to find the station name, warning time,
max_failures, cfg_failure_handlers and cfg_interfaces.
The warning_time is obtained either from $cfg_max_time or $cfg_max_jobtime.
The latter is jobtype-specific.  If a job is not found in this array, 
$cfg_max_time is used, if specified.

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# StaMon.pm,v 1.8 2008/09/16 21:46:21 clynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P::StaMon;
use File::Basename;
use Safe;
use S4P;
use Class::Struct;
    struct 'S4P::StaMon' => {
        dir => '$',
        job_type => '$',
        name => '$',
        set_umask => '$',
        group => '$',
        n_run => '$',
        n_pend => '$',
        n_suspend => '$',
        n_warn => '$',
        n_jobs => '$',
        n_fail_jobs => '$',
        n_fail_work_orders => '$',
        got_hold => '$',
        warning_time => '$',
        warning_jobtime => '%',
        interfaces => '%',
        failure_handlers => '%',
        count_since => '$',
        success_count => '$',
        failure_count => '$',
        max_failures => '$',
        max_children => '$',
        work_order_pattern => '$',
        input_work_order_suffix => '$',
        counter_log_file => '$',
        counter_file_pos => '$',
        jobs => '@',
        status => '@',
        anomalies => '$',
        failed_work_order_dir => '$',
        disable => '$',
        station_status => '$',
        case_log => '$'
    };
sub create {
    my ($substation, $count_since) = @_;
    my $delim = ($^O =~ /Win32/) ? ';' : ':';
    my ($dir, $job_type) = split($delim, $substation);
    my $stamon = new S4P::StaMon;
    $stamon->dir($dir);
    $stamon->job_type($job_type) if ($job_type);
    $stamon->configure();
}
sub configure {
    my $stamon = shift;
    my $dir = $stamon->dir;

    # Initialize configuration variables
    %cfg_interfaces = ();
    %cfg_failure_handlers = ();
    %cfg_max_jobtime = ();
    $cfg_counter_logfilename = 'station_counter.log';
    $cfg_station_name = basename($dir);
    $cfg_max_time = 0;
    $cfg_failed_work_order_dir = 'FAILED.WORK_ORDERS';
    $cfg_input_work_order_suffix = 'wo';
    $cfg_work_order_pattern = '';
    $cfg_max_failures = undef;
    $cfg_max_children = 5;
    $cfg_disable = 0;
    $cfg_umask = 0;

    # Read station configuration file
    if (! -e "$dir/station.cfg") {
        S4P::logger('WARN', "Station $dir has no station.cfg file");
    }
    else {
        my $cpt = Safe->new('CFG');
        $cpt->share(qw($cfg_counter_logfilename $cfg_station_name
            %cfg_max_jobtime $cfg_max_time $cfg_failed_work_order_dir
            $cfg_input_work_order_suffix $cfg_work_order_pattern
            $cfg_max_failures $cfg_max_children $cfg_umask
            %cfg_interfaces %cfg_failure_handlers $cfg_disable $cfg_case_log));
        $cpt->rdo("$dir/station.cfg") or 
            warn "Cannot parse $dir/station.cfg: $!";
    }

    # Set object attributes
    $stamon->counter_log_file("$dir/$CFG::cfg_counter_logfilename");
    my $name = $CFG::cfg_station_name;
    my $job_type = $stamon->job_type;
    my $delim = ($^O =~ /Win32/) ? ';' : ':';
    $name .= ($delim . $job_type) if $job_type;
    $stamon->name($name);
    $stamon->set_umask($cfg_umask);
    $stamon->group($CFG::cfg_group);
    if (%CFG::cfg_max_jobtime) {
        my ($key, $val);
        while (($key, $val) = each %CFG::cfg_max_jobtime) {
            $stamon->warning_jobtime($key, $val);
        }
    }
    $stamon->warning_time($CFG::cfg_max_time) if $CFG::cfg_max_time;
    $stamon->failed_work_order_dir($CFG::cfg_failed_work_order_dir);
    $stamon->input_work_order_suffix($CFG::cfg_input_work_order_suffix || 'wo');

    # Set (pending) work order pattern
    my $wo_pattern = $CFG::cfg_work_order_pattern ||
         S4P::work_order_pattern($S4P::work_order_prefix,
             $CFG::cfg_input_work_order_suffix);
    # Convert from glob to Perl regular expression
    $wo_pattern =~ s/\./\\./;
    $wo_pattern =~ s/\*/.*/;
    $wo_pattern=~ tr/?{,}/.(|)/;
    $stamon->work_order_pattern($wo_pattern);

    $stamon->max_failures($CFG::cfg_max_failures) if $CFG::cfg_max_failures;
    $stamon->max_children($CFG::cfg_max_children) if defined $CFG::cfg_max_children;
    $stamon->count_since($count_since);

    # Set cfg_interfaces and cfg_failure_handlers
    foreach (keys %CFG::cfg_interfaces) {
        $stamon->interfaces($_, $CFG::cfg_interfaces{$_});
    }
    foreach (keys %CFG::cfg_failure_handlers) {
        $stamon->failure_handlers($_, $CFG::cfg_failure_handlers{$_});
    }
    $stamon->disable($CFG::cfg_disable) if defined($CFG::cfg_disable);
    $stamon->case_log($CFG::cfg_case_log) if $CFG::cfg_case_log;
    return $stamon;
}
sub refresh {
    my $this = shift;
    my %param = @_;
    my $skip_counters = 1 if $param{'-skip_counters'};

    $this->station_status(S4P::check_station($this->dir));
    opendir(STATION, $this->dir) or return 0;
    my ($n_run, $n_pend, $n_warn, $n_fail_jobs, $n_fail_wo, $n_suspend);

    # Formulate work order pattern
    # Are we looking for a specific type?
    my $find_type = $this->job_type();

    # Set time for late arrivals
    my $now = time();
    my $def_warning_time = $this->warning_time if $this->warning_time;
    my $warning_time = $this->warning_jobtime($1) || $def_warning_time;
    my $late = ($now - $warning_time) if $warning_time;

    my $n_job;
    my $dir = $this->dir;
    my $wo_pattern = $this->work_order_pattern;
    my @anomalies;

    # Form job, status and time arrays
    # Status:  
    #    a=failed work_order
    #    b=failed job
    #    c=warning 
    #    d=suspended (reserved for future use)
    #    e=running
    #    f=pending
    foreach $_(readdir STATION) {
        next if (/^\./);   # Skip hidden directories
        # Skip if not for the job_type we want for this substation
        next if ($find_type && $_ !~ /\.$find_type\./);
        # Running jobs:  could be running fine or running late
        if (/$S4P::running_job_pattern/) {
            # See if job is running late
            # Look for job type
            m/RUNNING\.(\w+)\./;
            
            if ($late && $late > (stat("$dir/$_"))[10]) {
                $n_warn++;
                $this->status($n_job, 'c');
            }
            elsif (-f "$dir/$_/SUSPEND") {
                $n_suspend++;
                $this->status($n_job, 'd');
            }
            else {
                $n_run++;
                $this->status($n_job, 'e');
            }
            $this->jobs($n_job, $_);
            $n_job++;
        }
        elsif (/$S4P::failed_job_pattern/) {
            # Handle the failed work order directory, if it exists
            my $failedwo_name = $this->failed_work_order_dir();
            if (/^\Q$failedwo_name\E/) {
                my $pathname = "$dir/$failedwo_name";
                if (! opendir (WOSTATION, $pathname)) {
                    S4P::logger('ERROR', "Cannot open $pathname: $!");
                    next;
                }
                my $wo;
                foreach $wo(grep !/^\.\.?$/, readdir(WOSTATION)) {
                    $n_fail_wo++; 
                    $this->jobs($n_job, "$failedwo_name/$wo"); 
                    $this->status($n_job, 'a');
                    $n_job++;
                }
                closedir(WOSTATION);
            }
            # Failed jobs
            else {
                $n_fail_jobs++;
                $this->status($n_job, 'b');
                $this->jobs($n_job, $_);
                $n_job++;
            }
        }
        # Pending jobs
        elsif (/^(PRI\d\.)*${wo_pattern}$/) {
            $n_pend++;
            $this->status($n_job, 'f');
            $this->jobs($n_job, $_);
            $n_job++;
        }
        elsif (/^ANOMALY-(.*)\.log/) {
            push @anomalies, $1;
        }
    }
    $this->anomalies(join(',', @anomalies));
    $this->n_jobs($n_job);
    closedir(STATION);
    $this->n_run($n_run);
    $this->n_pend($n_pend);
    $this->n_suspend($n_suspend);
    $this->n_warn($n_warn);
    $this->n_fail_jobs($n_fail_jobs);
    $this->n_fail_work_orders($n_fail_wo);
    $this->update_counters() unless $skip_counters;

    $this->check_hold();
    return 1;
}
sub check_hold {
    use strict;
    my $this = shift;
    $this->got_hold(0);
    # Check .hold (S4PA convention)...
    my $hold_dir = $this->dir . "/.hold";
    # ... and HOLD (S4PM convention)
    $hold_dir = $this->dir . "/HOLD" unless (-d $hold_dir);
    return unless (-e $hold_dir);

    my $wo_pattern = $this->work_order_pattern;
    # Open hold directory and return as soon as we see a pending work order
    opendir(HOLD, $hold_dir) or return 0;
    foreach (readdir HOLD) {
        if (/^(PRI\d\.)*${wo_pattern}$/) {
            $this->got_hold(1);
            last;
        }
    }
    closedir(HOLD);
}
sub update_counters {
    my ($this, $since) = @_;
    my ($success_count, $failure_count);
    my $filename = $this->counter_log_file;
    if (! -e $filename) {
        return;
    }
    # Open counter log file
    if (! open(LOG, $filename) ) {
        S4P::logger("WARN", "Cannot open counter logfile $filename: $!");
        return;
    }
    # Jump to where we last left off
    if ($this->counter_file_pos) {
        seek(LOG, $this->counter_file_pos, 0);
        $success_count = $this->success_count;
        $failure_count = $this->failure_count;
    }
    my $line_time;
    my $since = $this->count_since;

    my $this_type = $this->job_type;
    my ($status, $job_type);
    while (<LOG>) {
        # Read through log file until we get to the right epochal time
        ($line_time) = m/.*EPOCH=(\d+)/;
        next if ($line_time < $since);
        # Parse for status and job_type
        if (/(SUCCESSFUL|FAILED)\s+(\S+)/) {
            $status = $1;
            $job_type = $2;
            # If this is restricted to a job_type then make sure we have a match
            next if ($this_type && $this_type ne $job_type);
            if ($status eq 'SUCCESSFUL') {
                $success_count++;
            }
            elsif ($status eq 'FAILED') {
                $failure_count++;
            }
        }
    }
    $this->counter_file_pos(tell(LOG));
    close(LOG);
    $this->success_count($success_count);
    $this->failure_count($failure_count);
    return 1;
}
1;
