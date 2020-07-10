package S4P::Job;
use S4P;
use S4P::Station;
use strict;
1;

sub new {
    my ($pkg, %params) = @_;

    # Can't have an S4P job outside a station
    # (Need all those config parameters)
    unless ($params{'station'}) {
        S4P::logger('ERROR', "Must pass a S4P::Station object to create a new job");
        return;
    }
    my $station = $params{'station'};

    # Can't have an S4P job without a work order
    unless ($params{'work_order'}) {
        S4P::logger('ERROR', "Must pass a work order file to create a new job");
        return;
    }
    my $work_order = $params{'work_order'};

    # Parse work order file name
    my ($job_type, $job_type_and_id, $priority, $rerun) =
        S4P::parse_job_type($work_order, $station->work_order_pattern);
    my ($dummy, $id) = split('\.', $job_type_and_id, 2);

    # Make object and populate structure
    my $job = bless \%params, $pkg;
    $job->type($job_type);
    $job->id($id);
    $job->priority($priority);
    $job->rerun($rerun);
    $job->station($station);
    $job->work_order($work_order);
    return $job;
}
sub call_perl_function {
    my $this = shift;
    my @cmd_args = @_;
    my $r_function = shift @cmd_args;

    my $station = $this->station;
    my ($rc, $ret_string);
    unless ($rc = &$r_function(@cmd_args)) {
        $ret_string = "Job (perl module call) failed";
    }

    # N.B.: convention for failure (0) is opposite from system call
    return (!$rc, $ret_string);
}  # Endif Perl Package

sub execute {
    my $this = shift;
    my $use_fork = $this->station->max_children;
    my $file = $this->work_order;
    # Make job directory
    my $rc = $this->make_job_dir;

    # Failed to make directory
    unless (defined($rc)) {
        $use_fork ? exit(106) : return(0);
    }

    # Not an error, but no job to process (e.g., ignore_duplicates)
    if ($rc == 0) {
        $use_fork ? exit(0) : return(1);
    }
    # Append work order on to end of logfile
#    log_work_order($newfile, $logfile);
    $this->log_work_order;
    S4P::logger("INFO", "Running child with work order $file");

    # Formulate command line
    my @cmd_args = (split ' ', $this->command);
    push @cmd_args, $this->runfile;
    # Write job.status file
    S4P::write_job_status('', 'RUNNING', $this->work_order, join(' ',@cmd_args));

    # Get run token (if necessary)
    my $token = $this->get_token or return 0;

    my $log_stats = $this->station->log_statistics;
    my ($ret_string, $exit_code);
    # Perl function (needs testing...)
    my $start_time = time() if $log_stats;
    if ($cmd_args[0] =~ /::/) {
        ($ret_string, $exit_code) =  $this->call_perl_function(@cmd_args);
    }
    else {
        ($ret_string, $exit_code) = $this->exec_cmd(@cmd_args); 
    }
    if ($exit_code == 0) {
       stop_stats($start_time) if $log_stats;
       $this->finish_job();
    }
    else {
       S4P::update_job_status('.', "FAILED $ret_string");
       $this->fail_job($ret_string);
    }
    # Return 0 if job failed
    if ($use_fork) {
        exit($exit_code ? 99 : 0);
    }
    else {
        return (! $exit_code);
    }
}

sub exec_cmd {
    my ($this, @cmd_args) = @_;
#    my ($job_type, $logfile, @cmd_args) = @_;
    # Win32 likes separate arguments better
    my ($ret_string, $exit_code);
    if ($S4P::is_win32) {
        ($ret_string, $exit_code) = S4P::exec_system(@cmd_args);
    }   
    # Unix shell likes args together for capture of
    # stderr & stdout
    else {
        my $job_deadline = $this->station->job_deadline;
        my $end_job_interval = $this->station->end_job_interval;
        my $logfile = $this->logfile;
        my $cmd = join(' ', @cmd_args) . " >> $logfile 2>&1";
        if ($end_job_interval) {
            S4P::logger('DEBUG', "running nervous_system with interval of $end_job_interval");
            my $deadline = (ref $job_deadline) 
                              ? $job_deadline->{$this->job_type} 
                              : $job_deadline;
            S4P::logger('DEBUG', "Job deadline=$deadline") if $deadline;
            ($ret_string, $exit_code) = S4P::nervous_system($end_job_interval, 
                $deadline, $cmd);        
        } 
        else {
            ($ret_string, $exit_code) = S4P::exec_system($cmd);
        }   
    }
    return ($ret_string, $exit_code);
}

# Job execution came back with non-zero exit
# fail_job will move the job to a FAILED.* directory
sub fail_job {
    my ($this, $text) = @_;
    unless ($text) {
        my ($pkg, $fname, $line) = caller();
        $text = "$fname, $pkg at line $line";
    }
    
    my $station = $this->station;
    S4P::fail_job($this->name, $text, 1, $station->case_log, 
       $station->rename_retries, $station->rename_retry_interval, $this->token);
}

##########################################################################
# fail_to_execute():  rename work order that failed to be executed
#   and put it in the FAILED.WORK_ORDERS directory
##########################################################################
sub fail_to_execute {
    my $this = shift;
    my $file1 = $this->work_order;
    my $file2 = $file1;
    my $fail_dir = $this->station->failed_work_order_dir;
    my $input_suffix = $this->station->input_work_order_suffix;
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
###########################################################################
# finish_job($job_id, $logfile, $newfile, $file, $newdir, \@downstream, 
#     $priority, $token):
# ------------------------------------------------------------------------
#   After work order is completed, send output workorders downstream and
#   cleanup directory, removing input work order and then the job directory
###########################################################################
sub finish_job {
    my $this = shift;
    my $station = $this->station;
#    my ($job_id, $logfile, $newfile, $file, $newdir, $r_downstream, 
#        $priority, $token) = @_;
    my $job_name = $this->name;

    # N.B.:  We are reversing the return code convention here because the
    # child process is going to exit with this return code shortly after this
    # function returns.

    my $rc = 0;
    S4P::logger("INFO", "done with work order " . $this->work_order);
    # Cleanup S4P-specific files
    unlink('job.status');
    unlink('job.message') if (-e 'job.message');
    if (defined($station->downstream) && 
        ! S4P::send_downstream($this->logfile, $station->downstream, 
            $this->priority, $station->root, 
            $station->output_work_order_suffix)) {
       S4P::logger("FATAL", "cannot move output work order(s)");
       $rc = 2;
    }
    elsif (! unlink $this->runfile) {
       S4P::logger("FATAL", "cannot delete work order: $!");
       $rc = 1;
    }
    else {
        my $logfile = $this->logfile;
        my @remaining_files = grep !/$logfile/, <*>;
        my $dir = $this->dir;
        if (scalar(@remaining_files) > 0) {
            S4P::logger("FATAL", 
                "leftover non-log files: Cannot remove directory $dir");
            foreach my $leftover(@remaining_files) {
                S4P::logger("ERROR", "Leftover file: $leftover");
            }
            $rc = 3;
        }
        elsif (-e $logfile && ! unlink($logfile)) {
            S4P::logger("FATAL", "Cannot remove logfile $logfile: $!");
            $rc = 4;
        }
        elsif (! (chdir '..' && rmdir $dir )) {
            S4P::logger("FATAL", "Cannot remove work order subdirectory $dir: $!");
            $rc = 5;
        }
    }
    if ($rc) {
        my $newname = "FAILED.$job_name." . abs($$);
        S4P::logger("INFO", "Renaming RUNNING.$job_name to $newname");
        chdir '..' if ($rc < 5);   # Never got that far in the process...
        S4P::rename_job_dir("RUNNING.$job_name", $newname, 
            $station->rename_retries, $station->rename_retry_interval) or
            S4P::logger("FATAL", "Failed to rename RUNNING.$job_name to $newname");
    }
    # Release any token that was being used
    S4P::release_token($this->token) if $this->token;

    S4P::counter(($rc ? 'FAILED' : 'SUCCESSFUL') . ' ' . $this->type);
    return $rc;
}
sub get_token {
    my $this = shift;
    # Check for run token if necessary
    my $station = $this->station;
    my $rh_tokens = $station->token or return 1;
    my $job_type = $this->type;
    my $token;
    if ($rh_tokens->{$job_type}) {
        S4P::logger('DEBUG', "Obtaining a token for job type $job_type");
        my $wait = 3600;
        my $interval = 5;
        $token =  S4P::request_token($rh_tokens->{$job_type},
            getcwd(), $this->name, $wait, $interval);
        if (! $token){
            $this->fail_job("Failed to get run token from $rh_tokens->{$job_type} after $wait secs");
            return 0;
        }
    }
    $this->token($token);
    return $token;
}
##########################################################################
# log_work_order():  save input work order into the
#   mobile log file (the one that trails along in the job chain, not the
#   station log) 
##########################################################################
sub log_work_order {
    my $this = shift;
    my $logfile = $this->logfile;
    my $runfile = $this->runfile;
    if (! open (LOGFILE, ">>", $logfile)) {
        S4P::logger("FATAL", "Cannot open log file $logfile");
        return 0;
    }    
    print LOGFILE '=' x 72, "\n";
    printf LOGFILE "%s %-5.5d %s\n", S4P::timestamp(), $$,  
        $this->station->station_name;
    if (! open WORKORDER, $runfile) {
        S4P::logger("FATAL", "Cannot open work order file $runfile");
        return 0;
    }    
    while (<WORKORDER>) { print LOGFILE; }
    close WORKORDER;
    print LOGFILE "-" x 72, "\n";
    close LOGFILE;
    return 1;
}

sub make_job_dir {
    my $this = shift;
    # Create a directory for job and chdir there
    
    my $priority = $this->priority || '';
    my $job_id = $this->id;
    my $job_name = $this->name;
    my $newdir = "RUNNING.$priority$job_name";
    my $file = $this->work_order;
    # If $rerun, reuse the old directory
    # N.B.:  this feature is little-used and little-tested!

    # Check to see if directory already exists
    if (! $this->rerun && -d $newdir) {
        S4P::raise_anomaly('SLOW_FS', '.', "ERROR", 
            "directory $newdir already exists", 0);
        if ($this->station->ignore_duplicates) {
            return 0;
        }
        else {
            $this->fail_to_execute;
            return;
        }
    }
    # Create directory for job to run in
    # If $rerun, reuse the old directory
    if (! $this->rerun && ! mkdir($newdir, 0775)) {
        S4P::logger("FATAL", "Cannot mkdir $newdir: $!");
        rename_work_order($file);
        return;
    }
    # Change into new job directory
    # Move work order and log file to new job directory
    my $newfile = "DO.$job_name";
    if (! rename($file, "$newdir/$newfile")) {
        S4P::logger("FATAL", "directory $newdir already exists");
        $this->fail_to_execute;
        return;
    }
    my $logfile = "$job_name.log";
    $ENV{'LOGFILE'} = $logfile;
    if (-e $logfile) {
        rename $logfile, "$newdir/$logfile";
    }
    # Change into new job directory
    chdir $newdir;
    $this->dir($newdir);
    $this->logfile($logfile);
    $this->runfile($newfile);
    return 1;
}

# Whether we have reached max_failures for this job_type
sub max_failures_reached {
    my $this = shift;
    my $rh_max_failures_reached = $this->station->max_failures_reached
        or return 0;
    return exists($rh_max_failures_reached->{$this->type});
}
sub prepare {
    my $this = shift;
    my $station = $this->station;
    my $type = $this->type;
    # Decrement reservations
    if ($station->reservations) {
        if (exists $station->open_slots->{$type} && 
            $station->open_slots->{$type} > 0) 
        {
            $station->open_slots->{$type}--;
        }
        elsif ($station->open_slots->{WALK_IN} > 0) {
            $station->open_slots->{WALK_IN}--;
        }
        else {
            S4P::logger("DEBUG", "Neither job_type nor walk_in slot available for " . $this->work_order . ", skipping to next job...");
            return;
        }
    }

    # Avoid warning of undefined var
    $this->priority('') unless defined($this->priority);

    # Misnomer: JOB_ID is combined job_type and job_id
    my $job_type_id = $this->type . '.' . $this->id;
    $ENV{'JOB_ID'}=$job_type_id;

    my $command;
    if (! ($command=$this->station->find_command($this->type)) ) {
        S4P::raise_anomaly('BAD_CONFIG', '.', "FATAL",
            "No command for job type " . $this->type . 
            " in config file; expecting "
            . join(' or ', sort keys %{$this->station->commands}), 2);
        $this->fail_to_execute;
        return;
    }
    $this->command($command);

    S4P::logger ("INFO","Running job $job_type_id with command $command and work order " . $this->work_order);
}
sub run {
    my $this = shift;
    $this->prepare or return;
    my $use_fork = ($this->station->max_children > 0);
    my $n_children = $this->station->num_running;
    my $pid;
    if ($use_fork && ($pid = fork())) {
        # Parent here
        # child process is $pid
        # Increment number of children so we can check against max_children
        $n_children++;
        $this->station->num_running($n_children);
        S4P::logger ("INFO", "$n_children children running...\n");
        # Wait for the first child to fork (shouldn't take long)
        waitpid($pid, 0);
    }
    elsif (!$use_fork || defined $pid) {
        # Child 1 here or no-fork
        # Now do a second fork for the real work, allowing the parent to
        # get on with its life.
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
                close $this->station->lock_handle;

                # Grandchild here:  wait for child 1 to exit
                my $child_sleep = $this->station->child_sleep;
                sleep($child_sleep) if ($child_sleep);
            }
        }
        $this->execute;
    }
}

############### Attributes set/get
sub command {my $this=shift; defined($_[0]) ? $this->{command}=$_[0] : $this->{command} }

sub id {my $this=shift; defined($_[0]) ? $this->{id}=$_[0] : $this->{id} }

sub dir {my $this=shift; defined($_[0]) ? $this->{dir}=$_[0] : $this->{dir} }

sub name {my $this=shift; ($this->type . '.' . $this->id) }

sub logfile {my $this=shift; defined($_[0]) ? $this->{logfile}=$_[0] : $this->{logfile} }

sub priority {my $this=shift; defined($_[0]) ? $this->{priority}=$_[0] : $this->{priority} }

sub rerun {my $this=shift; defined($_[0]) ? $this->{rerun}=$_[0] : $this->{rerun} }

# runfile is the filename after renaming into the job directory, i.e. 
# with the work_order_suffix dropped off
sub runfile {my $this=shift; defined($_[0]) ? $this->{runfile}=$_[0] : $this->{runfile} }

sub station {my $this=shift; defined($_[0]) ? $this->{station}=$_[0] : $this->{station} }

sub token {my $this=shift; defined($_[0]) ? $this->{token}=$_[0] : $this->{token} }

sub type {my $this=shift; defined($_[0]) ? $this->{type}=$_[0] : $this->{type} }

sub work_order {my $this=shift; defined($_[0]) ? $this->{work_order}=$_[0] : $this->{work_order} }
