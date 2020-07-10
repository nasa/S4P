
=head1 NAME

TkJob - view what's going on in an S4P job

=head1 SYNOPSIS

use S4P::TkJob;

my $tkjob = new S4P::TkJob($parent, $dir)

=head1 DESCRIPTION

This is a module used by tkstations.pl to enable drill down, etc.
It displays the various files in a job directory, allowing the 
user to view them.  There are also check boxes that allow user
to select filesize, date, and time to view.

It displays the files in a directory in an upper list box.  For a station, this
will show you which jobs are running and which are failed, each of which has
its own directory.  By double-clicking on the directory, you can drill down
into it for more info on the files.  By entering a word to search and pushing
the search button, a user can search within the lower list box.

The bottom box displays the contents of the file that is currently selected in
the top list box.  This allows you to view the configuration files, log files, 
etc.  It also has the capability to display the contents of simple dbm files.

=head1 FILES

=over 4

=item station.cfg

The station configuration file is read when in a station directory or its job
subdirectory.  It is used to locate station-specific interfaces 
(%cfg_interfaces) or job handlers (%cfg_manual_overrides or 
%cfg_failure_handlers).
These are hashes where the key is a button label and the value is the command
to be executed when the button is pressed.

The %cfg_interfaces buttons are available only in the Station directory.
The %cfg_failure_handlers buttons are available only in a I<failed> job
directory.
The %cfg_manual_overrides buttons are available only in a I<running> job
directory.

=back

=head1 SEE ALSO

Monitor(3), tkstations(1)

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# TkJob.pm,v 1.11 2008/09/15 15:12:06 clynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P::TkJob;
use Tk;
use Tk::ROText;
use Tk::Menubutton;
use Safe;
use S4P;
use S4P::S4PTk;
use Cwd;
use File::Basename;
use DB_File;
use Getopt::Std;
use strict;

1;

sub new {
    my ($pkg, $parent, $dir, %args) = @_;

    my %obj_hash;
    my $file;

    # If "$dir" is actually a file, go to the parent directory
    if (-f $dir) {
        $file = basename($dir);
        $dir = ($dir =~ m#/#) ? dirname($dir) : '.';
    }

    # Change to the requested directory
    chdir($dir) or return undef;
    my $current_dir = cwd();
    $obj_hash{'current_dir'} = $current_dir;
    $obj_hash{'previous_dir'} = dirname($current_dir) || $current_dir;
    
    # Build interface
    my $main = $parent ? $parent->Toplevel() : new MainWindow();
    $main->title("S4P: tkjob " . basename($current_dir));
    $obj_hash{'main_window'} = $main;

    # The station_status and job_status will always be used by reference, as
    # they are bound to widgets, so we treat them as references to scalars
    my ($station_status, $job_status, $entry_status,
        $size_status, $date_status, $time_status);
    $obj_hash{'station_status'} = \$station_status;
    $obj_hash{'job_status'} = \$job_status;
    $obj_hash{'size_status'} = \$size_status;
    $obj_hash{'date_status'} = \$date_status;
    $obj_hash{'time_status'} = \$time_status;
    $obj_hash{'entry_status'} = \$entry_status;
    while (my ($key, $val) = each(%args)) {
        $obj_hash{$key} = $val;
    }
    my $r_tkjob = \%obj_hash;
    bless $r_tkjob, $pkg;

    # Buttons
    $r_tkjob->main_button_frame;
    $r_tkjob->station_button_frame($main);
    $r_tkjob->job_button_frame($main);
    $r_tkjob->display_button_frame($main);

    # Listbox showing files in current directory
    my $listbox = $main->Scrolled('Listbox', -width=>60, -scrollbars=>'e',
    -selectmode=>'single',-exportselection=>1)->pack(-expand=>1, -fill=>'both');

    # Attach methods to Listbox:  
    #   single click shows file in bottom frame
    #   double click changes to that directory
    $listbox->bind('<Any-Button>' => [\&show_file, $r_tkjob]);
    $listbox->bind('<space>' => [\&show_file, $r_tkjob]);
    $listbox->bind('<Any-Double-Button>' => [\&drill_down, $r_tkjob]);
    $listbox->bind('<Return>' => [\&drill_down, $r_tkjob]);
    $r_tkjob->listbox($listbox);

    # Search button frame 
    $r_tkjob->search_button_frame($main);

    # Text in bottom frame
    my $text = $main->Scrolled('ROText', -scrollbars=>'e')->pack(-expand=>1, -fill=>'both');
    $text->insert('end','<No file selected>');
    $r_tkjob->text($text);

    # Initially set checkboxes 
    ${$r_tkjob->size_status} = 1;
    ${$r_tkjob->date_status} = 1;
    ${$r_tkjob->time_status} = 1;

    # Run refresh and go into main loop
    $r_tkjob->refresh(1);
    $r_tkjob->select($listbox, $file) if $file;
    return $r_tkjob;
}
###########################################################################
# refresh - refresh the screen
sub refresh {
    my $this = shift;
    my $update_buttons = shift;
    
    if (! -d $this->current_dir) {
        if (-d $this->previous_dir) {
            chdir $this->previous_dir;
            $this->current_dir(cwd());
        }
        else {
            S4P::logger('INFO', "Previous directory (" . $this->previous_dir. 
                ") is gone; window will exit");
            $this->main_window->destroy;
        }
    }
    else {
        my $dir = cwd();
        chdir $this->current_dir if ($dir ne $this->current_dir);
    }
    my @files = get_dir_listing($this->current_dir,$this);
    chomp(@files);

    # Clear the file list box and add the files
    my $listbox = $this->listbox;
    $listbox->delete(0, 'end');
    $listbox->insert('end', '..', @files);

    # Clear the text box
    my $text = $this->text;
    $text->delete('0.0', 'end');

    if ($update_buttons) {
        # Set the start/stop buttons depending on whether station is up
        $this->configure_station_buttons();
        $this->configure_job_buttons();
        $this->configure_job_control_buttons();
    }
}
sub select {
    my ($this, $listbox, $file) = @_;
    my ($line, $name);
    # Get all elements in the listbox
    my @elements = $listbox->get(0, 'end');
    my $n = scalar(@elements);
    my $i;
    # Loop through items in listbox
    for ($i = 0; $i < $n; $i++) {
        # Filename is the first word in the line
        my ($name) = split(/\s+/, $elements[$i]);
        if ($name eq $file) {
            # Clear any existing selections
            $listbox->selectionClear(0, 'end');
            # Set selection to the found one
            $listbox->selectionSet($i);
            show_file($listbox, $this);
            return;
        }
    }
}
###########################################################################
# main_button_frame - create the top frame with the buttons
###########################################################################
sub main_button_frame {
    my $this = shift;
    my $parent = $this->main_window;
    my $frame = $parent->Frame();
    $frame->Button(-text=>'Refresh', -command=>[\&refresh, $this, 1])->pack(-side=>'left');
    $frame->Button(-text=>'Close', -command=>[\&close_window, $this])->pack(-side=>'left');
    $frame->pack(-fill=>'x',-anchor=>'ne');
    $this->main_frame($frame);
    return $frame;
}
###########################################################################
# station_button_frame - create the top frame with the buttons
###########################################################################
sub station_button_frame {
    my ($this, $parent) = @_;
    my $frame = $parent->Frame();

    # If in a station directory, check to see if it's up...
    $frame->Label(-text=>'Station Processing: ', 
                  -pady => 10)->pack(-side=>'left');
    my @station_buttons = ();
    push @station_buttons, $frame->Radiobutton(-text=>'Start',
                             -value=>1,
                             -command=>[\&start_station, $this->classic],
                             -variable=>$this->station_status)->pack(-side=>'left');
    push @station_buttons, $frame->Radiobutton(-text=>'Stop',
                             -value=>0,
                             -command=>[\&shutdown_station, $this],
                             -variable=>$this->station_status)->pack(-side=>'left');
    my $anomaly_button = $frame->Button(-text=>'Clear Anomaly',
        -state=>'disabled')->pack(-side=>'left');

    # All done, now finish with a pack
    $frame->pack(-fill=>'x',-anchor=>'ne');
    $this->station_frame($frame);
    $this->station_buttons(\@station_buttons);
    $this->anomaly_button($anomaly_button);
    return ($frame, @station_buttons);
}
###########################################################################
# job_button_frame - create the top frame with the buttons
###########################################################################
sub job_button_frame {
    my $this = shift;
    my $parent = shift;
    my $frame = $parent->Frame()->pack(-side=>'top',-anchor=>'w');
    my %job_button;
    $frame->Label(-text=>'Job Control:         ', -pady=>10)->pack(-side=>'left');
    $job_button{'Terminate'} = $frame->Button(-text=>'Terminate', 
          -command=>[\&terminate_job, $this])->pack(-side=>'left');

    # If in a station directory, check to see if it's up...
    $job_button{'Suspend'} = $frame->Radiobutton(-text=>'Suspend',
                             -value=>'SUSPENDED',
                             -command=>[\&suspend_job, $this],
                             -variable=>$this->job_status)->pack(-side=>'left');
    $job_button{'Resume'} = $frame->Radiobutton(-text=>'Resume',
                             -value=>'RUNNING',
                             -command=>[\&resume_job, $this],
                             -variable=>$this->job_status)->pack(-side=>'left');

    # All done, now finish with a pack
    $this->job_frame($frame);
    $this->job_buttons(\%job_button);
    return ($frame, %job_button);
}
###########################################################################
# display_button_frame - create the top frame with the buttons
###########################################################################
sub display_button_frame {
    my ($this, $parent) = @_;
    my $frame = $parent->Frame();

    $frame->Label(-text=>'Display Control:      ',-pady=>10)->pack(-side=>'left');
    my @display_buttons = ();
 
    push @display_buttons, $frame->Checkbutton(-text=>'Size',
                           -command=>[\&refresh,$this, 0],
                           -variable=>$this->size_status)->pack(-side=>'left');
    push @display_buttons, $frame->Checkbutton(-text=>'Date',
                           -command=>[\&refresh,$this, 0],
                           -variable=>$this->date_status)->pack(-side=>'left');
    push @display_buttons, $frame->Checkbutton(-text=>'Time',
                           -command=>[\&refresh,$this, 0],
                           -variable=>$this->time_status)->pack(-side=>'left');
    # All done, now finish with a pack
    $frame->pack(-fill=>'x',-anchor=>'ne');
    $this->display_frame($frame);
    $this->display_buttons(\@display_buttons);
    return ($frame, @display_buttons);
}

###########################################################################
# search_button_frame - configure buttons based on job status
###########################################################################
sub search_button_frame {
    my ($this,$parent) = @_;
    my $frame = $parent->Frame();
    my $search_buttons;

    # Create search button
    $search_buttons = $frame->Button(-text=>'Search', 
                      -command=>[\&search, $this])->pack(-side=>'left');
    # Create text entry 
    $frame->Entry(-textvariable => $this->entry_status,
                      -borderwidth=>2,-justify=>'left',
                      -relief=>'sunken')->pack(-side=>'left');

    # All done, now finish with a pack
    $frame->pack(-fill=>'x',-anchor=>'ne');
    $this->search_frame($frame);
    $this->search_buttons(\$search_buttons);
    return ($frame, $search_buttons);

}
###########################################################################
# configure_job_buttons - configure buttons based on job status
###########################################################################
sub configure_job_buttons {
    my $this = shift;
    my %buttons = %{$this->job_buttons};
    my $cwd = cwd();
    my $dir = basename($cwd);
    if ($dir =~ /^FAILED/) {
        $buttons{'Terminate'}->configure(-state=> 'disabled');
        $buttons{'Resume'}->configure(-state=> 'disabled');
        $buttons{'Suspend'}->configure(-state=> 'disabled');
    }
    elsif ($dir =~ /^RUNNING/) {
        my ($job_status, $pid, $owner, $comment) = S4P::check_job($cwd);
        ${$this->job_status} = $job_status;
        $buttons{'Terminate'}->configure(-state=> 'normal');
        if ($job_status eq 'SUSPENDED') {
            $buttons{'Resume'}->configure(-state=> 'normal');
            $buttons{'Suspend'}->configure(-state=> 'disabled');
        }
        else {
            $buttons{'Resume'}->configure(-state=> 'disabled');
            $buttons{'Suspend'}->configure(-state=> 'normal');
        }
    }
    else {
        # Disable the buttons if not a job directory
        map {$_->configure(-state=> 'disabled')} values %buttons;
    }
}
###########################################################################
# configure_job_control_buttons - configure buttons based on job status
###########################################################################
sub configure_job_control_buttons {
    my $this = shift;
    my $cwd = cwd();
    my $dir = basename($cwd);
    my $frame = $this->job_frame;
    if ($this->failure_menu) {
        $this->failure_menu->destroy;
        delete $this->{'failure_menu'};
    }
    if ($this->override_menu) {
        $this->override_menu->destroy;
        delete $this->{'override_menu'};
    }

    if ($dir =~ /^FAILED/) {
       # If we came straight into the FAILED directory at window creation,
       # fill in stuff that would ordinarily be already set.
       if (! $this->cfg_failure_handlers) {
           %CFG::cfg_failure_handlers = () if %CFG::cfg_failure_handlers;
           S4P::read_safe_config('../station.cfg');
           my %failure_handlers = %CFG::cfg_failure_handlers;
           $this->cfg_failure_handlers(\%failure_handlers);
           $this->cfg_case_log($CFG::cfg_case_log) if ($CFG::cfg_case_log);
           $this->previous_dir(dirname(cwd()));
       }
       my $failure_menu = my_menu($frame, 'Failure Handlers...',
           [\&execute_handler, $this],
           $this->cfg_failure_handlers)->pack(-side=>'left');
       $this->failure_menu($failure_menu);
    }
    elsif ($dir =~ /$S4P::running_job_pattern/) {
       # If we came straight into the RUNNING directory at window creation,
       # fill in stuff that would ordinarily be already set.
       if (! $this->cfg_manual_overrides) {
           %CFG::cfg_manual_overrides = () if %CFG::cfg_manual_overrides;
           S4P::read_safe_config('../station.cfg');
           my %manual_override = %CFG::cfg_manual_overrides;
           $this->cfg_manual_overrides(\%manual_override);
           $this->previous_dir(dirname(cwd()));
       }
       my $override_menu = my_menu($frame, 'Manual Overrides...',
           [\&execute_handler, $this],
           $this->cfg_manual_overrides)->pack(-side=>'left');
       $this->override_menu($override_menu);
    }
    return 1;
}
sub my_menu {
    my ($parent, $title, $command, $rh_options) = @_;
    # Menu button from which to post menu
    my $mb = $parent->Menubutton(
        -indicatoron=>0,
        -relief=>'raised',
        -borderwidth=>2,
        -highlightthickness=>2,
        -anchor=>'c',
        -direction=>'flush',
        -text => $title,
    );
    # Create a child menu for our options
    my $menu = $mb->Menu(-tearoff=>0);
    my @callback = ref($command) =~ /CODE/ ? ($command) : @$command;
    # Execute callback with *value* in option hash
    foreach my $key(sort keys %$rh_options) {
        $menu->command(-label => $key, 
                       -command => [@callback, $rh_options->{$key}]);
    }
    # Associate child menu with menubar as a menu
    $mb->configure(-menu => $menu);
    return $mb;
}
###########################################################################
# configure_display_buttons - configure buttons based on job status
# Added by Long
###########################################################################
sub configure_display_buttons {
    my $this = shift;
    my @buttons = @{$this->display_buttons};

    # Setting the initial checkboxes
    ${$this->size_status} = 1;
    ${$this->date_status} = 1;
    ${$this->time_status} = 1;

    return 1;
}
###########################################################################
# configure_station_buttons - configure buttons based on stationmaster station
#     status
###########################################################################
sub configure_station_buttons {
    my $this = shift;
    my $frame = $this->station_frame;
    my @buttons = @{$this->station_buttons};

    my $dir = $this->current_dir;
    if ($this->interface_menu) {
        $this->interface_menu->destroy;
        delete $this->{'interface_menu'};
    }
    if (-e 'station.cfg') {
        # Make buttons active and check the station
        # Daemon status is linked to the radiobutton setting via $station_status
        map {$_->configure(-state=> 'active')} @buttons;
        ${$this->station_status} = S4P::check_station();

        # Look for interfaces to make available (%cfg_interfaces)
        %CFG::cfg_interfaces = () if %CFG::cfg_interfaces;
        S4P::read_safe_config('station.cfg');
        my %interfaces = %CFG::cfg_interfaces;
        $this->cfg_interfaces(\%interfaces);
        my %failure_handlers = %CFG::cfg_failure_handlers;
        $this->cfg_failure_handlers(\%failure_handlers);
        $this->cfg_case_log($CFG::cfg_case_log) if ($CFG::cfg_case_log);

        my $cmd_menu = my_menu($frame, 'Interfaces...', 
            [\&S4P::fork_command], \%interfaces);
        $cmd_menu->pack(-side=>'left');
        $this->interface_menu($cmd_menu);
    }
    else {
        # Disable the buttons if there is no station.cfg
        map {$_->configure(-state=> 'disabled')} @buttons;
    }
    return 1;
}
sub execute_handler {
    my $this = shift;
    my $exec = shift or return 1;
    my @args = @_;
    my $arg = join(' ', @args);

    # Get confirmation
    return 1 if (! S4P::S4PTk::confirm($this->main_window, "Execute $exec $arg?"));

    # Set temporary directory and file
    my $tmpdir = $ENV{'TMPDIR'} || '/usr/tmp';
    $tmpdir = '..' if (! -d $tmpdir);
    my $tmpfile = "$tmpdir/tkjob.$$";

    # Execute command
    my $cmd;
    # Sun apparently has a problem when you pass it an empty $arg; SGI doesn't
    if ( $arg ) {
        $cmd = "$exec $arg > $tmpfile 2>&1";
    }else {
        $cmd = "$exec > $tmpfile 2>&1";
    } 
    # Export case log file name to enviroment so that someone else may use it
    $ENV{'CBR_LOG_FILE'} = $CFG::cfg_case_log if ($CFG::cfg_case_log);

    my $dir = basename(cwd());
    my $station = undef;
    my $job_type = undef;
    my $job_id = undef;
    if ($dir =~ /^(RUNNING|FAILED)\.(.*?)\.(.*?)/) {
        $job_type = $2;
        $job_id = $3;
        $station = basename(dirname(cwd()));
    }

    my ($rs, $rc) = S4P::exec_system($cmd);

    if ($this->cfg_case_log) {
        # Failed job dir means failure recovery (R), else manual override (M)
        my $case_type = ($dir =~ /^FAILED/) ? 'R' : 'M';
        S4P::log_case($this->cfg_case_log, $case_type, $rc, "$exec $arg", $station, $job_type, $job_id);
    }

    # Display result to user
    my @output = `cat $tmpfile`;

    # Carve out middle if too many lines to show in popup
    if (scalar(@output) > 12) {
        splice(@output, 6, scalar(@output) - 6, "\n...(yadda, yadda)...\n");
    }
    if ($rc) {
        S4P::logger('ERROR', "$cmd failed: $rs!\n" . join("\n", @output));
    }
    else {
        S4P::logger('INFO', "$cmd successful.\n" . join("\n", @output));
    }
    unlink $tmpfile;
    $this->refresh(1);
    $this->main_window->raise;
    return 1;
    return (! $rc);
}
sub clear_anomaly {
    my ($this, $file, $dir, $tkjob) = @_;
    # Remove anomaly file
    S4P::clear_anomaly($file, $dir);
    # Refresh, since highlighted file is gone now
    $tkjob->refresh(1);
    # Gray out button
    $this->configure(-state=>'disabled');
}
###########################################################################
# search - search through currently file for entry 
###########################################################################
sub search {
    my ($this, $tkjob) = shift;
    my $cwd = cwd();
    my $txt_loc = "1.0";  
    my $cur_txt_loc = "1.0";

    my $text = $this->text;
    # Untag everything before a search
    $text->tagDelete('highlight');
    # Configure what to tag
    $text->tagConfigure('highlight', -background=>'red');
    # Search until no more is found
    while (1) {
        # Forward search, case insensitive
        $txt_loc = $text->search(-nocase, -forwards,${$this->entry_status},$cur_txt_loc,'end');
        # Exit loop if search returns empty 
        last if ($txt_loc eq "");
        # Tag text found
        $text->tagAdd('highlight',$txt_loc,"$txt_loc wordend");
        # Scroll to the location found
        $text->see($txt_loc);
        # Reset to new search location
        $cur_txt_loc = $txt_loc;
        # Move one character over
        $cur_txt_loc = "$cur_txt_loc + 1 chars";
    }
    return 0;
}
###########################################################################
sub suspend_job {
    my $this = shift;
    my $cwd = getcwd();
    print "Suspending job in $cwd\n";
    S4P::alert_job($cwd, 'SUSPEND');
    # Disable it so we can't keep suspending an already suspended job
    $this->job_buttons->{'Suspend'}->configure(-state=>'disabled');
    $this->job_buttons->{'Resume'}->configure(-state=>'normal');
}
sub resume_job {
    my $this = shift;
    my $cwd = getcwd();
    print "Resuming job in $cwd\n";
    S4P::alert_job($cwd, 'RESUME');
    $this->job_buttons->{'Resume'}->configure(-state=>'disabled');
    $this->job_buttons->{'Suspend'}->configure(-state=>'normal');
}
sub terminate_job {
    my $this = shift;
    return 0 if (! S4P::S4PTk::confirm($this->main_window, "Are you sure you want to terminate the job?"));
    my $dir = cwd();
    S4P::alert_job($dir, 'END') 
        ? S4P::logger('INFO', "Job terminated")
        : S4P::logger('ERROR', 'Failed to terminate job');
}
sub close_window {
    my $this = shift;
    my $main = $this->main_window;
    $main->destroy();
    return 1;
}
###########################################################################
# show_file - display contents of a "file":
#             text -> show text
#             dbm file -> show key => value
#             directory -> show file list
#             binary -> just show binary status
###########################################################################

sub show_file {
    my $self = shift;
    my $tkjob = shift;
    my $selection = $self->curselection;
    my ($file) = $self->get($selection,$selection);
    my $t;
    # Strip out the file name
    # $file =~ s/\s\s\(.*\)//;
    my @tmp_file = split(' ',$file);
    $file = $tmp_file[0];
    chomp($file);
    my $dir = $tkjob->current_dir;
    my $pathname = $dir . '/' . $file;
    if (! -e $pathname) {
        $t = "<File no longer exists - Click Refresh>\n";
    }
    elsif (-d $pathname) {
        my @dfile = get_dir_listing($pathname, $tkjob); 
        $t = "<Directory: $file>\n @dfile\n";
    }
    elsif ($pathname =~ /\.(db|dir|pag)$/) {
        # .dir or .pag indicates DBM database
        $t = "<DBM File>\n";
        my %db;
        my $db_type = 'DB_File' if ($file =~ /\.db$/);
        if ($db_type) {
            tie(%db, $db_type, $pathname) or 
                S4P::logger('ERROR', "Cannot display contents of $file: $!");
        }
        else {
            my $dbname = $pathname;
            $dbname =~ s/\.(dir|pag)$//;
            dbmopen(%db, $dbname, 0444);
        }
        map {$t .= $_ . ' => ' . $db{$_} . "\n"} sort keys %db;
        $db_type ? untie %db : dbmclose(%db);
    }
    elsif (! -s $pathname) {
        $t = "<Zero-length File>";
    }
    elsif (-B $pathname) {
        # Unrecognizable/uninterpertable binary file: punt
        $t = "<Binary File>";
    }
    elsif (!open IN, $pathname) {
        $t = "Cannot open $file: $!\n";
    }
    else {
        local($/)=undef;
        $t = <IN>;
        close IN;
    }
    my $text = $tkjob->text;
    $text->delete('0.0', 'end');
    $text->insert('end',$t);

    $text->see('end') if ($file =~ /log/i);

    # If selected file is an anomaly signal, activate Clear Anomaly button
    my $anomaly_button = $tkjob->anomaly_button();
    if ($file =~ /^ANOMALY-.*\.log/) {
        $anomaly_button->configure(-command=>[\&clear_anomaly, $anomaly_button, 
           $file, $dir, $tkjob], -state=>'active');
    }
    else {
        $anomaly_button->configure(-state=>'disabled');
    }
    return 1;
}
###########################################################################
# drill_down - descend into selected subdirectory and call refresh()
###########################################################################
sub drill_down {
    my $self = shift;
    my $tkjob = shift;
    # Get currently selected "file" (hopefully a directory)
    my $selection = $self->curselection;
    return if (! defined $selection);
    my ($file) = $self->get($selection,$selection);
    my @tmp_file = split(' ',$file);
    $file = $tmp_file[0];
    chomp($file);

    my $pathname = $tkjob->current_dir . '/' . $file;
    if (! -e $pathname) {
        show_file($self, $tkjob);
    }
    # If a directory, descend into it and call refresh()
    elsif (-d $pathname) {
        # Save current_dir as previous_dir
        $tkjob->previous_dir($tkjob->current_dir);

        # Change directories and reset current_dir
        chdir $pathname or return 0;
        $tkjob->current_dir(cwd());

        # Refresh
        my $main = $tkjob->main_window;
        $main->title("S4P: tkjob " . basename($tkjob->current_dir));
        $tkjob->refresh(1);
    }
    return 1;
}
###########################################################################
# shutdown_station - stop stationmaster station by extracting process_id from
###########################################################################
sub shutdown_station {
    my $this = shift;
    if (S4P::stop_station() == 9) {
        # Does this do anything?
       $this->refresh(1);
    }
    else {
       return 0;
    }
}
###########################################################################
# Fork off a station process IN THIS DIRECTORY
###########################################################################
sub start_station {
    my $classic = shift;
    my $station = shift;
    my $cmd = $classic ? 'stationmaster.pl' : 's4p_station.pl';
    my @args = ('-d', $station) if ($station);
    return S4P::fork_command($cmd, @args);
}
###########################################################################
# Get directory listing for current directory 
###########################################################################
sub get_dir_listing {
    my $var;
    my $filename;
    my @files;
    my $ON = 1;
    my $OFF = 0;
    my $SIZE;
    my $DATE;
    my $TIME;
   
    # Get current directory
    my ($dir, $this) = @_;
    chomp($dir);

    # Get current file parameters
    my $size_stat = ${$this->size_status};
    my $date_stat = ${$this->date_status};
    my $time_stat = ${$this->time_status};

    # Get current listing
    opendir (DIRHANDLE, $dir) || warn "Couldn't open $dir : $!";
    my @file_list = readdir(DIRHANDLE);
    # Loop through each file in list
    foreach $filename (@file_list) {
        chomp($filename);
        next if ($filename eq "." || $filename eq "..");
        # Get file statistics
        my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, 
            $atime, $mtime,$ctime, $blksize, $blocks) = stat "$dir/$filename";
        # Convert to local time & date
        my ($secs, $min, $hr, $mday, $mnth, 
            $yr, $wd, $yd, $ds) = localtime($mtime);
        # Create output string depends on what box was checked
        $SIZE = ($size_stat ==  $ON) ? sprintf("%d bytes",$size) : "";
        $DATE = ($date_stat == $ON) ? sprintf("%4d/%.2d/%.2d",$yr+1900,$mnth+1,$mday) : "";
        $TIME = ($time_stat == $ON) ? sprintf("%.2d:%.2d:%.2d",$hr,$min,$secs) :"";
        # Making sure it's a file
        if (-d $filename){
            # Special case for all off boxes
            if ($SIZE == $OFF && $DATE ==  $OFF && $TIME == $OFF) {
                $var = sprintf("%s/\n",$filename);
            }
            else {
                $var = sprintf("%s/  %s  %s  %s\n",$filename,$SIZE,$DATE,$TIME);
            }
        }
        else {
            if ($SIZE == $OFF && $DATE ==  $OFF && $TIME == $OFF) {
                $var = sprintf("%s\n",$filename);
            }
            else {
                $var = sprintf("%s  %s  %s  %s\n",$filename,$SIZE,$DATE,$TIME);
            }
        }
        push(@files,$var);
    }
    closedir (DIRHANDLE);
    return (sort(@files));
}
###########################################################################
sub previous_dir {my $this = shift; @_ ? $this->{'previous_dir'} = shift
                                       : $this->{'previous_dir'}}
sub current_dir {my $this = shift; @_ ? $this->{'current_dir'} = shift
                                       : $this->{'current_dir'}}
sub main_window {my $this = shift; @_ ? $this->{'main_window'} = shift
                                      : $this->{'main_window'}}
sub main_frame {my $this = shift; @_ ? $this->{'main_frame'} = shift
                                      : $this->{'main_frame'}}
sub station_frame {my $this = shift; @_ ? $this->{'station_frame'} = shift
                                      : $this->{'station_frame'}}
sub station_buttons {my $this = shift; @_ ? $this->{'station_buttons'} = shift
                                      : $this->{'station_buttons'}}
sub anomaly_button {my $this = shift; @_ ? $this->{'anomaly_button'} = shift
                                      : $this->{'anomaly_button'}}
sub listbox {my $this = shift; @_ ? $this->{'listbox'} = shift
                                  : $this->{'listbox'}}
sub text {my $this = shift; @_ ? $this->{'text'} = shift
                                  : $this->{'text'}}
sub job_frame {my $this = shift; @_ ? $this->{'job_frame'} = shift
                                  : $this->{'job_frame'}}
sub display_frame {my $this = shift; @_ ? $this->{'display_frame'} = shift
                                  : $this->{'display_frame'}}
sub search_frame {my $this = shift; @_ ? $this->{'search_frame'} = shift
                                  : $this->{'search_frame'}}
sub job_buttons {my $this = shift; @_ ? $this->{'job_buttons'} = shift
                                  : $this->{'job_buttons'}}
sub display_buttons {my $this = shift; @_ ? $this->{'display_buttons'} = shift
                                  : $this->{'display_buttons'}}
sub search_buttons {my $this = shift; @_ ? $this->{'search_buttons'} = shift
                                  : $this->{'search_buttons'}}
sub interface_menu {my $this = shift; 
    @_ ? $this->{'interface_menu'} = shift
                : $this->{'interface_menu'}}
sub failure_menu {my $this = shift; @_ ? $this->{'failure_menu'} = shift
                                  : $this->{'failure_menu'}}
sub override_menu {my $this = shift; @_ ? $this->{'override_menu'} = shift
                                  : $this->{'override_menu'}}
sub cfg_case_log {my $this = shift; @_ ? $this->{'cfg_case_log'} = shift
                                  : $this->{'cfg_case_log'}}
sub cfg_interfaces {my $this = shift; @_ ? $this->{'cfg_interfaces'} = shift
                                  : $this->{'cfg_interfaces'}}
sub cfg_failure_handlers {my $this = shift; @_ 
                                  ? $this->{'cfg_failure_handlers'} = shift
                                  : $this->{'cfg_failure_handlers'}}
sub cfg_manual_overrides {my $this = shift; @_ 
                                  ? $this->{'cfg_manual_overrides'} = shift
                                  : $this->{'cfg_manual_overrides'}}
sub station_status {my $this = shift; @_ ? $this->{'station_status'} = shift
                                  : $this->{'station_status'}}
sub job_status {my $this = shift; @_ ? $this->{'job_status'} = shift
                                  : $this->{'job_status'}}
sub size_status {my $this = shift; @_ ? $this->{'size_status'} = shift
                                  : $this->{'size_status'}}
sub date_status {my $this = shift; @_ ? $this->{'date_status'} = shift
                                  : $this->{'date_status'}}
sub time_status {my $this = shift; @_ ? $this->{'time_status'} = shift
                                  : $this->{'time_status'}}
sub entry_status {my $this = shift; @_ ? $this->{'entry_status'} = shift
                                  : $this->{'entry_status'}}
sub classic {my $this = shift; @_ ? $this->{'classic'} = shift
                                  : $this->{'classic'}}
