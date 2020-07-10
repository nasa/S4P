#!/usr/bin/perl

=head1 NAME

tkargus - window view multiple S4P strings

=head1 SYNOPSIS

tkargus.pl
B<-c> I<config_file> 
[B<-a> I<appname>] 
[B<-b>] 
[B<-f> I<font>] 
[B<-r> I<refresh_rate>] 
[B<-t> I<title>] 

=head1 DESCRIPTION

This is a highly abstracted station monitor, designed for monitoring 
multiple S4P "strings" at once.  (It is named after Argus Panoptes of 
Greek Mythology, who had 100 eyes.)
The display is a grid with S4P strings running down the columns and stations 
running across as rows.  The display for a given station in a given string is
the "most important" status and statistic:

If the station is disabled, the disable color (default=gray) or bitmap is shown.

Otherwise, if a station is down, the down color (default=black) or bitmap is 
shown.  If there are failed jobs, the number of failed jobs is displayed.

If a station is up, but has failed work orders and/or jobs, the failed color 
(default=red) (or bitmap) is shown, along with the total number of failed 
work orders and jobs.

If a station is up, with no failures, but has tardy jobs, the warning color 
(default=yellow) (or bitmap) is shown, along with the number of tardy jobs.

If a station is up and there are running jobs, the nominal color 
(default=green) (or bitmap) and number of running jobs are shown.

Otherwise, if a station is up and there are pending jobs, the pending color 
(default=blue) (or bitmap) and number of pending jobs are shown.

Mousing over a box will show all the job statistics for that station in that 
string.

Clicking on a box will bring up the tkstat.pl interface for that station/string.

=head1 ARGUMENTS

=over 4

=item B<-a> I<appname>

Set the application name, as recognized by the X resource database.
This allows you to start it up with different X resource values
(and gets around the apparent bug causing subsequent instances of a given
user's client to ignore the X resource database.)

=item B<-f> I<font>

Set the font for the whole interface.  
B<N.B.: Make sure to quote it if the font begins with a hyphen, as most do.>

=item B<-i> I<refresh_interval>
Time between refresh cycles, i.e., before it begins refreshing each machine's
columns.  Default is 120.
Compare with B<-r> I<refresh_rate>.

=item B<-r> I<refresh_rate>

Refresh rate in seconds. This is the time lag between each machine during a
single refresh cycle.  Default is 5.
Compare with B<-i> I<refresh_interval>.

N.B.:  Because this program ssh's to other machines, you don't want 
this number to be too low.  A single refresh takes several seconds per machine.

=item B<-b>

Use bitmaps to display station status.  If this option is chosen, the following
default bitmaps are used:  FAILED = circle with diagonal line (a.k.a. "error");
WARNING = exclamation point (a.k.a. "warning"); RUNNING = hourglass; PENDING =
question mark (a.k.a. "question"); ERROR = questhead (failed to get info on station)

=item B<-t> I<title>

String to display in title bar.

=item B<-c> I<config_file>

Full pathname of required configuration file which contains a hash
B<%cfg_string> that describes the strings being monitored:

   %cfg_string{$machine}{$code} = $dir;

The directory is the root directory for the string, while the $code is a
shorthand term for the string used in the display.

Also, the array B<@cfg_sort_stations> must be specified for the 
stations to be displayed

    @cfg_sort_stations = ('station','station',...);

Use the B<$cfg_station_name> value in the station's configuration file, 
not the directory name.

Example:

  $cfg_strings{'daacmac17.gsfc.nasa.gov'}{'alpha'} = '/Users/clynnes/alpha';
  $cfg_strings{'daacmac17.gsfc.nasa.gov'}{'baker'} = '/Users/clynnes/baker';
  $cfg_strings{'localhost'}{'charlie'} = '/Users/clynnes/charlie';

  @cfg_sort_stations = (
    'Acquire Data',
    'Allocate Disk',
    'Export',
    'Register Data',
    'Run Algorithm',
  );

=back

=head1 RESOURCES

tkargus can also use X Resources from the user's .Xdefaults or .Xresources
file. Aside from the usual ones for the widgets herein (font settings for
Button widgets, foreground settings, etc.), the following are supported:

=over 4

=item failedColor (class FailedColor)

Color to display for failed jobs. Default is red.

=item pendingColor (class PendingColor)

Color to display for pending jobs. Default is blue.

=item runningColor (class RunningColor)

Color to display for running jobs. Default is forest green (#228b22).

=item warningColor (class WarningColor)

Color to display for late-running jobs.  Default is yellow.

=item failedBitmap (class FailedBitmap)

Bitmap to display for failed jobs if B<-b> option is specified
Default is 'error' (circle with diagonal line).

=item pendingBitmap (class PendingBitmap)

Bitmap to display for pending jobs if B<-b> option is specified.
Default is 'question' (question mark).

=item runningBitmap (class RunningBitmap)

Bitmap to display for running jobs if B<-b> option is specified.
Default is 'hourglass'.

=item warningBitmap (class WarningBitmap)

Bitmap to display for late-running jobs if B<-b> option is specified.
Default is 'warning' (exclamation point).

=item errorBitmap (class ErrorBitmap)

Bitmap to display for failure to get info on a station.  Default is 'questhead'.

=item infoBitmap (class infoBitmap)

Bitmap to display for station that is down.  Default is 'info'.

=back

=head1 SEE ALSO

S4PMonitor(3), tkstat(1)

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# tkargus.pl,v 1.3 2008/03/19 18:50:38 lynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use Tk;
use Tk ':eventtypes';
use Getopt::Std;
use File::Basename;
use Cwd;
use Safe;
use Sys::Hostname;
use strict;
use vars qw($opt_a $opt_b $opt_f $opt_i $opt_r $opt_R $opt_t $opt_c);

use S4P;
use S4P::S4PTk;

# Parse command line options
getopts('a:bf:i:r:Rt:c:');

# Suppress annoying DEBUG messages
$ENV{'OUTPUT_DEBUG'} = 0;

my (%cfg_strings, %cfg_sort_stations, @cfg_sort_stations);
# If configuration file has been passed, read it in
if ( $opt_c ) {
    my $cpt = Safe->new('CFG');
    $cpt->share('%cfg_strings', '@cfg_sort_stations');
    if (! $cpt->rdo($opt_c)) {
        warn ("Cannot parse config file $opt_c");
        exit(2);
    }
    %cfg_strings = %CFG::cfg_strings or die "No strings found in config file $opt_c";;
    if (@CFG::cfg_sort_stations) {
        my @sort = @CFG::cfg_sort_stations;
        %cfg_sort_stations = (map {($sort[$_], $_)} 0..$#sort);
    }
}
else {
    die "Usage: tkargus.pl -c config_file [-b] [-a appname] [-f font] [-i refresh_interval] [-r refresh_rate] [-t title]\n";
}

# Initialize global scratch arrays
my (%string_status, %string_columns, $status_text);
my $rh_string_status = \%string_status;
my $rh_string_columns = {%CFG::cfg_strings};
my $rs_status = \$status_text;

# First fetch string statuses, so we can figure out what stations we will 
# need to setup in the rows
my $ra_stations = [@CFG::cfg_sort_stations];
my @machines = sort keys %cfg_strings;
my @strings = map {sort keys %{$cfg_strings{$_}}} @machines;
my $n_strings = scalar(@strings);

# Create Main window
my $main = MainWindow->new();
my $title = $opt_t || "S4P:  Argus";
$main->title($title);
S4P::S4PTk::redirect_logger($main);
$main->appname($opt_a) if $opt_a;

# Read in .Xdefaults / .Xresources
S4P::S4PTk::read_options($main);

# Create Monitor hash, using Xresources if set
# This allows us to pass the whole kit and kaboodle around the various callbacks.
my $monitor = {
    'error_color' => ($main->optionGet('errorColor','ErrorColor') || 'pink'),
    'disable_color' => ($main->optionGet('disableColor','DisableColor') || 'gray50'),
    'down_color' => ($main->optionGet('downColor','DownColor') || 'black'),
    'failed_color' => ($main->optionGet('failedColor','FailedColor') || 'red'),
    'running_color' => ($main->optionGet('runningColor','RunningColor') || '#228b22'),
    'warning_color' => ($main->optionGet('warningColor','WarningColor') || 'yellow'),
    'pending_color' => ($main->optionGet('pendingColor','PendingColor') || 'blue'),
    'error_bitmap' => ($main->optionGet('errorBitmap','ErrorBitmap') || 'questhead'),
    'disable_bitmap' => ($main->optionGet('disableBitmap','DisableBitmap') || 'gray25'),
    'down_bitmap' => ($main->optionGet('downBitmap','DownBitmap') || 'info'),
    'failed_bitmap' => ($main->optionGet('failedBitmap','FailedBitmap') || 'error'),
    'warning_bitmap' => ($main->optionGet('warningBitmap','WarningBitmap') || 
        'warning'),
    'running_bitmap' => ($main->optionGet('runningBitmap','RunningBitmap') || 
        'hourglass'),
    'pending_bitmap' => ($main->optionGet('pendingBitmap','PendingBitmap') || 
        'question'),
    'empty_bitmap' => ($main->optionGet('emptyBitmap','EmptyBitmap') || 
        'transparent'),
    'main_window' => $main,
    'strings' => \%cfg_strings,
    'string_status' => $rh_string_status,
    'string_columns' => $rh_string_columns,
    'stations' => $ra_stations,
    'n_strings' => $n_strings,
    'status_text' => $rs_status,
    'current_machine' => 0,
    'refresh_interval' => 0,
    'refresh_rate' => 0,
    'timer' => 0,
};

fetch_string_status($monitor, 1);

# Set height/width for bitmaps if opt_b is specified
my ($height, $width) = ($opt_b ? (20, 20) : (1, 3));

# Set font
$main->optionAdd("*font", $opt_f) if $opt_f;

# Create frame for station grid
my $gridframe = $main->Frame()->pack(-fill=>'x');

# Create header rows above station grid
grid_header($gridframe, $monitor, $main, \@machines);

# Loop through stations, create a row for each one
my $station;
my %station_buttons;
foreach $station (sort sort_stations @{$monitor->{'stations'}}) {
    my @buttons = station_row($gridframe, $monitor, $station, $height, $width, $n_strings);
    $station_buttons{$station} = \@buttons;
}

# Initialize variables for use of you_are_here() (mouse-over) procedure
our $you_are_here = "                                    ";
my $here_label = here_label($main, \$you_are_here);

# Put in bottom button frame with Refresh and Exit
set_check_time(\$status_text);
my $button_frame = button_frame($main, $monitor, \$status_text);

# Set refresh rate
my $refresh_rate = $opt_r || $main::cfg_refresh_rate || 5;
my $refresh_interval = $opt_i || $main::cfg_refresh_interval || 120;
$monitor->{'refresh_rate'} = $refresh_rate;
$monitor->{'refresh_interval'} = $refresh_interval;
# Set timer to expired so we can start off with a refresh
$monitor->{'timer'} = $refresh_interval;  
$main->repeat($refresh_rate * 1000, [\&recheck_next, $monitor]);

# Run refresh and go into main loop
recheck_next($monitor);
MainLoop();

exit (0);

###########################################################################
# recheck_all($monitor)
#   $monitor - Monitor hash
# -------------------------------------------------------------------------
# Recheck and refresh the screen at regular intervals with updated job status:
# Fetch the new string status for all strings and then refresh the display
###########################################################################
sub recheck_all {
    my $monitor = shift;
    my @machines = sort keys %{$monitor->{'strings'}};
    map {recheck_machine($monitor, $_)} @machines;
    # Reset timer since we just checked them all
    $monitor->{'timer'} = 0;
}
sub recheck_next {
    my $monitor = shift;
    my $refresh_rate = $monitor->{'refresh_rate'};
    my $refresh_interval = $monitor->{'refresh_interval'};

    # Check refresh interval to see if it is time to start another cycle
    if  ($monitor->{'timer'} < $refresh_interval) {
        $monitor->{'timer'} += $refresh_rate;
        return;
    }

    # OK, we got past the interval timer.
    # Let's see how far along we are in the refresh cycle...
    my $current = $monitor->{'current_machine'};
    my @machines = sort keys %{$monitor->{'strings'}};
    my $n_machines = scalar(@machines);

    # If we have finished all the machines, then reset timer and current_machine
    if ($current >= $n_machines) {
        $monitor->{'current_machine'} = 0;
        $monitor->{'timer'} = 0;
        return;
    }

    # Time's up!  Let's refresh this machine
    my $main = $monitor->{'main_window'};
    $main->Busy(-recurse => 1);
    recheck_machine($monitor, $machines[$current]);
    $main->Unbusy(-recurse => 1);

    # Increment the machine for the next step in this refresh cycle
    $monitor->{'current_machine'}++;

    # Return control to MainLoop() so we can refresh what we have now
    return 1;
}
sub recheck_machine {
    my ($monitor, $machine, $main) = @_;
    fetch_string_status($monitor, 0, $machine);
    refresh_machine($monitor, $machine);
}
sub refresh_machine {
    my ($monitor, $machine, $ra_stations) = @_;
    my %string_status = %{$monitor->{'string_status'}};
    foreach my $code(sort keys %{$string_status{$machine}}) {
        refresh_string($monitor, $machine, $code, $ra_stations);
    }
}
sub refresh_string {
    my ($monitor, $machine, $code, $ra_stations) = @_;
    my @stations = @$ra_stations if $ra_stations;
    @stations = sort sort_stations @{ $monitor->{'stations'} } unless @stations;
    foreach $station( @stations ) {
        my $col = $monitor->{'station_columns'}->{$machine}->{$code};
        my $button = $station_buttons{$station}[$col];
        my %button_info = %{$string_status{$machine}{$code}{$station}};
        update_button($button, $monitor, \%button_info);
    }
}
###########################################################################
# grid_header($parent, $monitor)
#   $parent - parent window
#   $monitor - Monitor hash
# -------------------------------------------------------------------------
# Create header above job grid
##########################################################################
sub grid_header {
    use strict;
    my ($parent, $monitor, $main, $ra_machines) = @_;
    my $col = 1;
    my $n_strings = $monitor->{'n_strings'};
    my $i;
    my %string_columns = %{$monitor->{'string_columns'}};
    my @string_labels;
    my $key_label = $parent->Label(-text => 'Machine')->grid;
    my $col = 1;
    foreach my $machine(@$ra_machines) {
        my $n_string;
        foreach my $code(sort keys %{$string_columns{$machine}}) {
            push(@string_labels, $parent->Label(-text=>$code, -relief=>'groove'));
            $n_string++;
        }
        my $w_machine = $parent->Button(-text=>$machine, -padx => 0, -pady => 0,
          -command=>[\&recheck_machine, $monitor, $machine, $main])
          ->grid(-row=>0, -column=>$col, -columnspan=>$n_string, -sticky=>'ew');
        $col += $n_string;
    }
    my $key_label = $parent->Label(-text => 'Station', -padx => 0, -pady => 0, 
           -bd => 1)->grid(@string_labels, -padx=>1, -pady=>0, -sticky=>'we');
}

###########################################################################
# station_row($parent, $monitor, $station, $height, $width)
#   $parent - parent window
#   $monitor - Monitor hash
#   $station - SubStation object
#   $height - button height in pixels if bitmaps are used, rows otherwise
#   $width - button width in pixels if bitmaps are used, characters otherwise
# -------------------------------------------------------------------------
# Create row for a whole station: station button, job buttons and counters
###########################################################################
sub station_row {
    use strict;
    my ($parent, $monitor, $station, $height, $width) = @_;

    # Get string info from the monitor hash
    my %strings = %{$monitor->{'strings'}};
    my $host = hostname();  # To avoid unnecessary ssh's
    my @buttons;

    # Loop through machines in sorted order
    my $i = 0;
    foreach my $machine(sort keys %strings) {
        # ssh variable for tkstat commands to bind to button
        my $ssh = ($host eq $machine) ? '' : "ssh $machine ";
        foreach my $code(sort keys %{$strings{$machine}}) {
            $monitor->{'station_columns'}->{$machine}->{$code} = $i++;
            # Build tkstat command for button
            my $args = $opt_R ? '-R ' : '';
            if ($ssh) {
                $args .= "-t \\'tkargus/tkstat: $machine $code\\'";
            }
            else {
                $args .= "-t 'tkargus/tkstat: $machine $code'";
            }
            my $cmd = "$ssh tkstat.pl $args $rh_string_status->{$machine}{$code}{$station}{'dir'} &";
            # Create button for each string for this station
            my $button = $parent->Button( -height=>$height, -width=>$width, -text=>'  ',
                          -padx=>1, -pady=>1, -bd=>1, -highlightthickness=>1, 
                          -command => sub {warn "Executing $cmd\n"; S4P::exec_system($cmd)});
            push @buttons, $button;
            $button->bind('<Enter>', [\&you_are_here, $rh_string_status->{$machine}{$code}{$station}]);
            $button->bind('<Leave>', [\&you_are_here]);
        }
    }

    # Get normal background color for buttons for later use
    $monitor->{'empty_color'} ||= $buttons[0]->cget(-bg);

    # Put the buttons/labels all into a grid row, starting with a button
    # indicating the station name
    my $key_button = $parent->Label(-text => $station, -padx => 0, -pady => 0,
        -relief=>'groove', -anchor=>'e') ->grid(@buttons, -padx=>1, -pady=>0, -sticky=>'we');

    return @buttons;
}
###########################################################################
# update_button ($button, $monitor, $rh_button_info)
#   $button - Button to update
#   $monitor - Monitor object, with various colors, bitmaps, etc.
#   $start - button at which to start (accounts for pseudo-scrolling)
#   @buttons - array of buttons to update
# -------------------------------------------------------------------------
# update all of the buttons in a station row:  change station button color
# and button contents
###########################################################################
sub update_button {
    my ($button, $monitor, $rh_button_info) = @_;
    my ($color, $bitmap, $njobs);
    my $text = '  ';
    my $fg = 'black';
    # First determine if we got any info in our fetch_station_status call
    if (!$rh_button_info->{'flag'}) {
        $color = $monitor->{'error_color'};
        $bitmap = $monitor->{'error_bitmap'};
    }
    # If disabled, gray the station out for this string
    elsif ($rh_button_info->{'disable'}) {
        $color = $monitor->{'disable_color'};
        $bitmap = $monitor->{'disable_bitmap'};
    }
    # Otherwise, show the down color if the station is not up
    elsif (! $rh_button_info->{'up'}) {
        $color = $monitor->{'down_color'};
        $bitmap = $monitor->{'down_bitmap'};
        $njobs = $rh_button_info->{'n_fail'} + $rh_button_info->{'n_fail_wo'};
        # Down station could have failed jobs in it
        if ($njobs) {
            $text = (($njobs > 999) ? '999' : sprintf("%3d", $njobs));
            $fg = 'orange';
        }
        else {
            $njobs = $rh_button_info->{'n_pend'};
            $text = (($njobs > 999) ? '999' : sprintf("%3d", $njobs)) if $njobs;
            $fg = '#a0a0ff';
        }
    }
    # If running, but with failed jobs, show FAIL color and number of jobs/work orders
    elsif ($njobs = $rh_button_info->{'n_fail'} + $rh_button_info->{'n_fail_wo'}) {
        $color = $monitor->{'failed_color'};
        $bitmap = $monitor->{'failed_bitmap'};
        $text = ($njobs > 999) ? '999' : sprintf("%3d", $njobs);
        $fg = 'white';
    }
    # No failed jobs, but some jobs running late...
    elsif ($njobs = $rh_button_info->{'n_warn'}) {
        $color = $monitor->{'warning_color'};
        $bitmap = $monitor->{'warning_bitmap'};
        $text = ($njobs > 999) ? '999' : sprintf("%3d", $njobs);
    }
    # Everything nominal
    elsif ($njobs = $rh_button_info->{'n_run'}) {
        $color = $monitor->{'running_color'};
        $bitmap = $monitor->{'running_bitmap'};
        $text = ($njobs > 999) ? '999' : sprintf("%3d", $njobs);
        $fg = 'white';
    }
    # Nothing running, but pending jobs exist
    elsif ($njobs = $rh_button_info->{'n_pend'}) {
        $color = $monitor->{'pending_color'};
        $bitmap = $monitor->{'pending_bitmap'};
        $text = ($njobs > 999) ? '999' : sprintf("%3d", $njobs);
        $fg = 'white';
    }
    # Station running, but nothing else of interest going on
    else {
        $color = $monitor->{'empty_color'};
        $bitmap = $monitor->{'empty_bitmap'};
    }
    if ($opt_b) {
        $button->configure(-bitmap=>$bitmap);
    }
    else {
        $button->configure(-text => $text);
        $button->configure(-bg=>$color);
        $button->configure(-fg=>$fg);
    }
    return;
}
###########################################################################
# button_frame($parent, $monitor)
#   $parent - parent window (i.e., main window)
#   $monitor - monitor object, passed through to refresh()
# -------------------------------------------------------------------------
# Create a frame with Refresh and Exit buttons
###########################################################################
sub button_frame {
    my ($parent, $monitor, $rs_text) = @_;
    my $frame = $parent->Frame();
    $parent->Button(-text=>'Recheck All', 
        -command=>[\&recheck_all, $monitor, $rs_text])->pack(-side=>'left');
    $parent->Label(-textvariable => $rs_text)->pack(-side=>'left');
    $parent->Button(-text=>'Exit', -command=>sub{exit 0})->pack(-side=>'right');
    $frame->pack(-fill=>'x',-anchor=>'e');
    return $frame;
}
###########################################################################
# here_label($parent, $rs_here)
#   $parent - parent widget (i.e. main window)
#   $rs_here - reference to a scalar variable which will hold text
# -------------------------------------------------------------------------
# Set up a label at the bottom to hold the station stats when user mouses over a
# station box
###########################################################################
sub here_label {
    my ($parent, $rs_here) = @_;
    use strict;
    my $frame = $parent->Frame(-relief=>'sunken', -borderwidth=>2);
    my $label = $frame->Label(-textvariable => $rs_here);
    $label->pack(-side => 'left', -fill => 'both');
    $frame->pack(-fill=>'both',-anchor=>'e');
    return $frame;
}
###########################################################################
# you_are_here ($station, $rh_station_status)
#   $station - which station we're mousing over
#   $rh_station_status - hash ref for this station with all the stats
# -------------------------------------------------------------------------
# Show the station stats underneath when user mouses over station box
###########################################################################
sub you_are_here {
    my ($button, $rh_station_status) = @_;
    if ($rh_station_status) {
        $you_are_here = sprintf "Fail = %d  Warn = %d  Run = %d  Pend = %d",
            $rh_station_status->{'n_fail_wo'} + $rh_station_status->{'n_fail'},
            $rh_station_status->{'n_warn'}, $rh_station_status->{'n_run'},
            $rh_station_status->{'n_pend'};
    }
    else {
        $you_are_here = ' ';
    }
}
###########################################################################
# fetch_string_status ($rh_string_status, $rh_strings, $rs_text)
#   $rh_string_status - reference to complex hash with string information
#                       is modified on output
#   $rh_strings - reference to hash with root directories for each string
#                 hash is keyed on machine name and string "code" (shorthand
#                 name for string which is displayed in column headers)).
#   $rs_text - string variable to update status
sub fetch_string_status {
    my $monitor = shift;
    my $init = shift;
    my $rh_string_status = $monitor->{'string_status'};
    my $rh_strings = $monitor->{'strings'};
    my $rs_text = $monitor->{'status_text'};
    my $main = $monitor->{'main_window'};
    my %strings = %$rh_strings;
    my @machines = @_;
    @machines = sort keys %strings unless(@_);

    my %string_status = %$rh_string_status;
    my (%string_dir, %string_status, %stations, $n_strings);
    my $host = hostname();  # To avoid unnecessary ssh's
    my $errmsg;
    foreach my $machine(@machines) {
        # Build list of directories so we do only one SSH
        # Also build reverse hash for easy string lookup
        my @dirs;
        if ($rs_text) {
            $$rs_text = "Checking strings on $machine...";
            $main->update() unless $init;
        }
        else {
            warn "Checking strings on $machine...\n";
        }
        foreach my $code(keys %{$strings{$machine}}) {
            $n_strings++;
            my $dir = $strings{$machine}{$code};
            push (@dirs, $dir);
            $string_dir{$dir} = $code;
        }

        # Execute s4p_stat.pl command!
        my $cmd = join(' ', "s4p_stat.pl", @dirs);
        my @string_status;
        if (! $init) {
            my $ssh = ($machine eq 'localhost' || $host eq $machine) ? '' 
                      : "ssh $machine ";
            @string_status = `$ssh $cmd`;
            if ($?) {
                $errmsg .= "Could not execute $cmd on $machine\n";
                next;
            }
        }
        # Parse output from s4p_stat command.
        # Start of a string is recognized by String: at the beginning
        my ($cur_string, $cur_root);
        foreach (@string_status) {
            chomp;
            if (/^String:/) {
                s/^String:\s*//;
                $cur_string = $string_dir{$_};
                $cur_root = $_;
                 if (! $cur_string) {
                     S4P::logger("WARN", "Could not find directory $_ in list of strings");
                     next;
                 }
            }
            # Look for lines starting with Sta:
            # (Spurious login messages can confuse otherwise)
            elsif (/^\s*Sta:/) {
                my ($dummy, $sta_dir, $sta_name, $disable, $up, $n_fail_wo, $n_fail, $n_warn, $n_run, $n_pend) = split(':');
                $rh_string_status->{$machine}{$cur_string}{$sta_name}{'dir'} = "$cur_root/$sta_dir";
                $rh_string_status->{$machine}{$cur_string}{$sta_name}{'disable'} = $disable;
                $rh_string_status->{$machine}{$cur_string}{$sta_name}{'up'} = $up;
                $rh_string_status->{$machine}{$cur_string}{$sta_name}{'n_fail_wo'} = $n_fail_wo;
                $rh_string_status->{$machine}{$cur_string}{$sta_name}{'n_fail'} = $n_fail;
                $rh_string_status->{$machine}{$cur_string}{$sta_name}{'n_warn'} = $n_warn;
                $rh_string_status->{$machine}{$cur_string}{$sta_name}{'n_run'} = $n_run;
                $rh_string_status->{$machine}{$cur_string}{$sta_name}{'n_pend'} = $n_pend;
                $rh_string_status->{$machine}{$cur_string}{$sta_name}{'flag'} = 1;
                $stations{$sta_name}++;
            }
        }
    }
    # Fill in flag for any blank spots
    foreach my $machine(sort keys %string_status) {
        foreach my $code(keys %{$strings{$machine}}) {
            foreach my $station(keys %stations) {
#                $rh_string_status->{$machine}{$code}{$station}{'flag'} = 0;
            }
        }
    }
    # Get unique list of stations (useful only for first time through)
    my @stations = sort sort_stations (keys %stations);
    S4P::logger("WARN", $errmsg) if $errmsg;
    set_check_time($rs_text) if $rs_text;
    return 1;
}
sub set_check_time {
    my $rs_text = shift;
    my @t = localtime();
    $$rs_text = sprintf("Last checked: %02d:%02d:%02d", $t[2], $t[1], $t[0]);
}
sub sort_stations {
    return ($cfg_sort_stations{$a} <=> $cfg_sort_stations{$b})
        if (exists $cfg_sort_stations{$a} && exists $cfg_sort_stations{$b});
    return $cfg_sort_stations{$a} if exists $cfg_sort_stations{$a};
    return $cfg_sort_stations{$b} if exists $cfg_sort_stations{$b};
    return $a cmp $b;
}
