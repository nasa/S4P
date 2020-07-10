#!/tools/gdaac/COTS/perl-5.8.5/bin/perl

=head1 NAME

tkstat - view S4P stations

=head1 SYNOPSIS

tkstat.pl
[B<-a> I<appname>] 
[B<-b>] 
[B<-f> I<font>] 
[B<-m> I<max_blocks>] 
[B<-r> I<refresh_rate>] 
[B<-t> I<title>] 
[B<-c> I<config_file>] 
[B<-R>]
[B<-F>]
[B<-C>]
[station_dirs]

=head1 DESCRIPTION

This is a highly simplified station monitor.
It shows the jobs running at each station in a grid, with each station 
represented by a row.

Station directories or station.list files (lists of station directories)
can be specified on the command line. If nothing is specified, it will look
first for a station.list file in the current directory, and then for a
station.cfg file.

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

=item B<-F>

If set, disabled stations are not shown. Otherwise, disabled stations are
shown with their buttons grayed out and non functioning.

=item B<-m> I<max_blocks> 

Number of blocks to show in each row.  Default = 15.

=item B<-r> I<refresh_rate>

Refresh rate in seconds. Default = 5 secs.

=item B<-b>

Use bitmaps to display job status.  If this option is chosen, the following
default bitmaps are used:  FAILED = circle with diagonal line (a.k.a. "error");
WARNING = exclamation point (a.k.a. "warning"); RUNNING = hourglass; PENDING =
question mark (a.k.a. "question").

=item B<-t> I<title>

String to display in title bar.

=item B<-c> I<config_file>

Full pathname of an optional configuration file which contains a single hash,
%CFG::tkstat_commands, that allows user-defined buttons to be added to the 
bottom of the GUI. The hash keys are button names and the hash values are the
associated actions that are invoked by clicking on the button. The default 
buttons are 'Exit' and 'Refresh'. The maximum number of user-defined buttons 
is 6. The order of the user-defined buttons can optionally be specified by
prepending a number followed by a colon to the button names. The order of the
buttons will then be in numeric order; the numbers will be stripped off prior
to labeling the buttons with them. If no number + colon is prepended to the
button names, the order will be random, though likely in the order set by the
hash in the configuration file. Any button defined with a label containing
the string 'kill' (any case) will show up in red text in the GUI.

=item B<-C>

This option invokes "classic" mode whereby stationmaster.pl is called instead
of the newer s4p_station.pl. Note that stationmaster.pl is deprecated code
and will likely be removed at some future time (along with this option).

=item B<-R>

"Read-only".  For management types that want to see how things are going
without hurting anything.

=back

=head1 RESOURCES

tkstat can also use X Resources from the user's .Xdefaults or .Xresources
file. Aside from the usual ones for the widgets herein (font settings for
Button widgets, foreground settings, etc.), the following are supported:

=over 4

=item failedColor (class FailedColor)

Color to display for failed jobs. Default is red.

=item pendingColor (class PendingColor)

Color to display for pending jobs. Default is RoyalBlue.

=item suspendedColor (class SuspendedColor)

Color to display for pending jobs. Default is MidnightBlue.

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

=item suspendedBitmap (class suspendedBitmap)

Bitmap to display for suspended jobs if B<-b> option is specified.
Default is 'question' (question mark).

=item runningBitmap (class RunningBitmap)

Bitmap to display for running jobs if B<-b> option is specified.
Default is 'hourglass'.

=item warningBitmap (class WarningBitmap)

Bitmap to display for late-running jobs if B<-b> option is specified.
Default is 'warning' (exclamation point).

=item maxBlocks (class MaxBlocks)

Maximum number of jobs to display in a row. Default is 15.

=back

=head1 SEE ALSO

S4PMonitor(3), tkjob(1)

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# tkstat.pl,v 1.17 2009/08/13 21:51:28 clynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use S4P::TkJob;
use Tk;
use Tk::Balloon;
use Getopt::Std;
use File::Basename;
use Cwd;
use Class::Struct;
use Safe;
use S4P::StaMon;
use strict;
use vars qw($opt_a $opt_b $opt_f $opt_m $opt_M $opt_r $opt_t $opt_c $opt_R
            $opt_F $opt_C $cfgdir);
# globals only until we can time to implement a way to pass them reliably
use vars qw(%prev_colors @prev_colors $you_are_here $station_anomaly 
            %start_button);

# Parse command line options
getopts('a:bf:Mm:r:t:c:RFC');
# opt_M is ignored; left for backward compatibility

# Suppress annoying DEBUG messages
$ENV{'OUTPUT_DEBUG'} = 0;

# If configuration file has been passed, read it in
my $cfgfile;
if ( defined $opt_c and $opt_c ne "" ) {
    $cfgfile = $opt_c;
} else {
    $cfgfile = undef;
}
if ( $cfgfile ) {
    my $rc = read_tkstat_config($cfgfile);
    # Save current directory
    my $cwd = getcwd();

    # Change to directory where config file is
    my $dir = dirname($cfgfile);
    chdir($dir) or die "main: Cannot chdir to $dir: $!";

    # Get directory where the config file is
    $cfgdir = getcwd();
    chdir($cwd) or die "main:  Cannot chdir back to $cwd: $!";
}

# Initialize global scratch arrays
# Read in desired stations from command line
my @dir_array = get_station_dirs(@ARGV);
    
# Create Main window
my $main = MainWindow->new();
my $title = $opt_t || "S4P:  tkstat";
$main->title($title);
S4P::S4PTk::redirect_logger($main);
$main->appname($opt_a) if $opt_a;

# Read in .Xdefaults / .Xresources
S4P::S4PTk::read_options($main);

# Create StaMon objects
my $now;  # unused, for "now"
my @stamon = map {S4P::StaMon::create($_, $now)} @dir_array;
@stamon = filter_disabled(@stamon) if ( $opt_F );
die "No valid/active stations specified\n" unless (scalar(@stamon));

# Create S4PMonitor object, using Xresources if set
my $monitor = {
    'failed_color' => ($main->optionGet('failedColor','FailedColor') || 'red'),
    'running_color' => ($main->optionGet('runningColor','RunningColor') || '#228b22'),
    'warning_color' => ($main->optionGet('warningColor','WarningColor') || 'yellow'),
    'suspended_color' => ($main->optionGet('suspendedColor','SuspendedColor') || 'MidnightBlue'),
    'pending_color' => ($main->optionGet('pendingColor','PendingColor') || 'RoyalBlue'),
    'failed_bitmap' => ($main->optionGet('failedBitmap','FailedBitmap') || 'error'),
    'warning_bitmap' => ($main->optionGet('warningBitmap','WarningBitmap') || 
        'warning'),
    'running_bitmap' => ($main->optionGet('runningBitmap','RunningBitmap') || 
        'hourglass'),
    'pending_bitmap' => ($main->optionGet('pendingBitmap','PendingBitmap') || 
        'question'),
    'empty_bitmap' => ($main->optionGet('emptyBitmap','EmptyBitmap') || 
        'transparent'),
    'substations' => \@stamon};


# Reset max blocks if specified on command line
$opt_m ||= $main->optionGet('maxBlocks', 'MaxBlocks');
$monitor->{'max_blocks'} = $opt_m || 20;
my @colors = map {0} 1..$monitor->{'max_blocks'};
my @bitmaps = map {$monitor->{'empty_bitmap'}} 1..$monitor->{'max_blocks'};

# Set height/width for bitmaps if opt_b is specified
my ($height, $width) = ($opt_b ? (20, 20) : (1, 2));


# Set font
$main->optionAdd("*font", $opt_f) if $opt_f;

# Create frame for job grid
my $gridframe = $main->Frame()->pack(-fill=>'x');

# Create header above job grid
my $count_since;  # unused for now
grid_header($gridframe, $monitor, $count_since);

# Loop through (sub)stations, create a row for each one
my $substation;
my %station_buttons;
my $nrows = 1;  # 1 for the header
foreach $substation (@{$monitor->{'substations'}}) {
    my $menu = create_menu($gridframe, $substation);
    my @buttons = station_row($gridframe, $monitor, $substation, $height, $width, $menu);
    $station_buttons{$substation} = \@buttons;
    my @prev_colors = map {0} 1..$monitor->{'max_blocks'};
    $prev_colors{$substation} = \@prev_colors;
    $nrows++;
}

# Initialize variables for use of you_are_here() procedure
$station_anomaly = "";
$you_are_here = "";
my $nblocks = $monitor->{'max_blocks'};
my $status_row = $nrows + 1;
our $balloon = $main->Balloon();
since_button($gridframe, $monitor, $count_since, $status_row, $nblocks+3);


# Put in bottom button frame with Refresh and Exit
my $button_frame = button_frame($main, $monitor);

# Set refresh rate
my $refresh_rate = $opt_r || $CFG::cfg_refresh_rate || 5;
$main->repeat($refresh_rate * 1000, [\&refresh, $monitor]);

# Initialize start buttons for use by scroll_job and update_buttons
my $station;
foreach $station ( @{ $monitor->{'substations'}} ) {
    $start_button{$station} = 0;
}

# Run refresh and go into main loop
refresh($monitor);
MainLoop();

exit (0);

sub get_station_dirs {
    my @args = @_;
    my $cwd = cwd();
    # If no directories specified, first look for a station.list file,
    # next a station.cfg file (indicating 'current')
    unless (@args) {
        if (-f 'station.list') {
            push @args, 'station.list';
        }
        elsif (-f 'station.cfg') {
            push @args, $cwd;
        }
    }
    my @dirs;
    foreach my $arg(@args) {
        # If arg is really a station.list file, read the dirs from that
        my $dir = ($arg =~ m#^/#) ? $arg : "$cwd/$arg";
        my $real_dir = $dir;
        $real_dir =~ s/:[\w\.\-]+//;   # Remove "zoom" part of dir
        if ($dir =~ /station.list$/) {
            push @dirs, read_station_list($cwd, $dir);
        }
        elsif (-f "$real_dir/station.cfg") {
            push @dirs, $dir;
        }
        else {
            warn "Error: directory $dir has no station.cfg\n";
        }
    }
    return @dirs;
}
sub read_station_list {
    my ($cwd, $stalist) = @_;
    my @dirs;

    # Open station list
    open(STA, $stalist) or die "Cannot open station list $stalist: $!";

    # Read one directory per line
    while (<STA>) {
        chomp;
        # Prepend cwd if not absolute path
        my $dir = ($_ =~ m#^/#) ? $_ : "$cwd/$_";
        # Check for station config file
        if (-f "$dir/station.cfg") {
            push @dirs, $dir;
        }
        else {
            warn "Error: directory $dir has no station.cfg\n";
        }
    }
    close STA;
    return @dirs;
}
    
###########################################################################
# read_tkstat_config($file)
# -------------------------------------------------------------------------
sub read_tkstat_config {
    use Safe;
    my $file = shift;
    my $cpt = new Safe('CFG');
    $cpt->rdo($file) or die "Failed to read config file $file\n";
}
###########################################################################
# reconfigure($monitor)
#   $monitor - S4PMonitor object
# -------------------------------------------------------------------------
# Reread station.cfg and then refresh
###########################################################################
sub reconfigure {
    my $monitor = shift;
    # For each station, reread the config files for the station
    foreach my $stamon( @{ $monitor->{'substations'} } ) {
        $stamon->configure;
    }
    refresh($monitor);
}
###########################################################################
# refresh($monitor)
#   $monitor - S4PMonitor object
# -------------------------------------------------------------------------
# Refresh the screen at regular intervals with updated job status
###########################################################################
sub refresh {
    my $monitor = shift;

    my $stamon;
    # For each station, update the buttons in the row
    foreach $stamon( @{ $monitor->{'substations'} } ) {
        $stamon->refresh;
        update_buttons($stamon, $monitor, $start_button{$stamon}, 
            \@{$station_buttons{$stamon}}, \@{$prev_colors{$stamon}});
    }
}
###########################################################################
# grid_header($parent, $monitor, $count_since)
#   $parent - parent window
#   $monitor - S4PMonitor object
#   $count_since - Time to which success/failure counter goes back
# -------------------------------------------------------------------------
# Create header above job grid
###########################################################################
sub grid_header {
    use strict;
    my ($parent, $monitor, $count_since) = @_;
    my $col = $monitor->{'max_blocks'};
    my $row1 = 1;
    $parent->Label(-text=>'Station')->grid(-row=>$row1);
    $parent->Label(-text=>'Jobs')->grid(-row=>$row1, -column=>1, -columnspan=>$col++);
    $parent->Label(-text=>'Queue')->grid(-row=>$row1, -column=>($col++), -sticky=>'e');
    $parent->Label(-text=>'Max')->grid(-row=>$row1, -column=>($col++), -sticky=>'e');
    $parent->Label(-text=>'OK')->grid(-row=>$row1, -column=>($col++), -sticky=>'e');
    $parent->Label(-text=>'Fail')->grid(-row=>$row1, -column=>($col++), -sticky=>'e');
#    since_button($parent, $monitor, $count_since, 0, $col);
}
sub since_button {
    my ($parent, $monitor, $count_since, $row, $col) = @_;
    my $since_text = "since\n$count_since";
    my $button = $parent->Button(
       -textvariable=>\$since_text, 
       -command => [\&update_since, \$since_text, $monitor],
       -padx=>1, -pady=>2)->grid(-row=>$row, -columnspan=>2, -column=>$col);
    update_since(\$since_text, $monitor);
}
###########################################################################
# update_since($monitor)
#   $monitor - S4PMonitor object
# -------------------------------------------------------------------------
# Update the time the counters are set to start from
###########################################################################
sub update_since {
    my ($rs_text, $monitor) = @_;

    # Get current time
    my $now = time;
    my @ctime = localtime($now);

    # Update button text
    $$rs_text = sprintf("since\n%02d/%02d %02d:%02d:%02d", $ctime[4]+1, 
        $ctime[3], $ctime[2], $ctime[1], $ctime[0]);

    # Update each station monitor object
    $monitor->{'count_since'} = $now;
    foreach my $stamon(@{$monitor->{'substations'}}) {
        $stamon->count_since($now);
        $stamon->success_count(0);
        $stamon->failure_count(0);
    }
}

###########################################################################
# station_row($parent, $monitor, $station, $height, $width, $menu)
#   $parent - parent window
#   $monitor - S4PMonitor object
#   $station - SubStation object
#   $height - button height in pixels if bitmaps are used, rows otherwise
#   $width - button width in pixels if bitmaps are used, characters otherwise
#   $menu - popup menu for right-click
# -------------------------------------------------------------------------
# Create row for a whole station: station button, job buttons and counters
###########################################################################
sub station_row {
    use strict;
    my ($parent, $monitor, $station, $height, $width, $menu) = @_;

    # Set up as many buttons as we have planned to allocate ($blocks)
    my $blocks = $monitor->{'max_blocks'};
    my @buttons = map {$parent->Button( -height=>$height, -width=>$width,
                           -padx=>0, -pady=>0, -bd=>0, -highlightthickness=>1)
                      } (1..$blocks);

    # Get normal background color for buttons for later use
    $monitor->{'empty_color'} ||= $buttons[0]->cget(-bg);

    # Add a callback with the index of the button in the row as the closure data
    my $i;
    for ($i = 0; $i < scalar(@buttons); $i++) {
        $buttons[$i]->configure(-command=>[\&drill_down, $station, $i]);
        $buttons[$i]->bind('<Enter>', [\&you_are_here, $station, $i]);
        $buttons[$i]->bind('<Leave>', [\&you_are_here]);
    }


    # Add number of pending jobs
    push @buttons, $parent->Label(-padx=>0, -pady=>0, -bd=>1, -justify=>'right',                                  -fg=>$monitor->{'pending_color'});
    # Show max children
    push @buttons, $parent->Label(-padx=>0, -pady=>0, -bd=>1, -justify=>'right', -text=>$station->max_children);
    # Add two "buttons" (labels really) which have counters of the number of
    # successful and failed jobs, respectively
    push @buttons, $parent->Label(-padx=>0, -pady=>0, -bd=>1,
                                  -fg=>$monitor->{'running_color'});
    push @buttons, $parent->Label(-padx=>0, -pady=>0, -bd=>1, 
                                  -fg=>$monitor->{'failed_color'});

 
    # Put the buttons/labels all into a grid row, starting with a button
    # indicating the station name
    my $key_button = $parent->Button(
        -text => $station->name, -padx => 0, -pady => 0, -bd => 1)->
            grid(@buttons, -padx=>1, -pady=>0, -sticky=>'we');
    $key_button->bind('<Enter>', [\&show_anomaly, $station]);
    $key_button->bind('<Leave>', [\&show_anomaly]);

    # Add the counter labels
    map {$buttons[$_]->grid(-sticky=>'e')} (-1,-2,-3,-4);

    $key_button->configure(-command=>[\&drill_down, $station, -1]);
    $key_button->bind('<ButtonPress-3>' => [\&popup_menu, $menu, $station]);

    # Color the station button red if the daemon is down
    show_station_status($station, $key_button, $monitor->{'failed_color'}, 
        $monitor->{'warning_color'}, $monitor->{'pending_color'});

    # Shift max_children label as we don't need it
#    shift @buttons if ($show_max);
    return $key_button, @buttons;
}
###########################################################################
# show_anomaly($station)
#   $station - substation object
# -------------------------------------------------------------------------
# Show the start of the anomaly field
###########################################################################
sub show_anomaly {
    my ($button, $stamon) = @_;
    if ($stamon) {
        my $string = $stamon->anomalies;
        # Trim the anomalies after the first
        $string =~ s/,.*/.../;
        $station_anomaly = $string;
        $balloon->attach($button, -balloonmsg=>$string);
    }
    else {
        $station_anomaly = '';
    }
}

###########################################################################
# drill_down($station, $job_number)
#   $station - substation object
#   $job_number - index in station job row of clicked button
# -------------------------------------------------------------------------
# Drill down into a station or job: i.e., bring up a TkJob window
###########################################################################
sub drill_down {
    my ($stamon, $job_number)  = @_;
    return 1 if ($opt_R);

    my %args = ('classic' => $opt_C);
    if ($job_number < 0) {
        return new S4P::TkJob($main, $stamon->dir, %args);
    }

    # Figure out which job it is by the number, offset by start_button
    my $job = get_job($stamon, $job_number);
    if ($job) {
        my $directory = sprintf "%s/%s", $stamon->dir, $job;
        return new S4P::TkJob($main, $directory, %args);
    }
    else {
        return 0;
    }
}
###########################################################################
# update_buttons ($station, $monitor, $start, \@buttons, \@prev_colors)
#   $station - StaMon object
#   $monitor - Monitor object, with various colors, bitmaps, etc.
#   $start - button at which to start (accounts for pseudo-scrolling)
#   @buttons - array of buttons to update
# -------------------------------------------------------------------------
# update all of the buttons in a station row:  change station button color,
# job colors, pseudo-scroll indicators, and success/fail counters
###########################################################################
sub update_buttons {
    my ($stamon, $monitor, $start, $ra_buttons, $ra_prev_colors) = @_;
    my @buttons = @{$ra_buttons};
    my $key_button = shift @buttons;
    my $n_buttons = @buttons;
    my $i = 0;
    my $n_fail = $stamon->n_fail_jobs + $stamon->n_fail_work_orders;

    # Check to see if daemon is up and color station button appropriately
    show_station_status($stamon, $key_button, $monitor->{'failed_color'}, 
        $monitor->{'warning_color'}, $monitor->{'pending_color'});

    # Go through the failed, warning, running and pending jobs:
    # Build up arrays of colors and bitmaps
    my (@colors, @bitmaps);
    my $n = $n_fail;
    for ($i = 0; $i < $n; $i++) {
        $colors[$i] = $monitor->{'failed_color'}; 
        $bitmaps[$i] = $monitor->{'failed_bitmap'} if $opt_b;
    }
    $n += $stamon->n_warn;
    for (; $i < $n; $i++) {
        $colors[$i]=$monitor->{'warning_color'}; 
        $bitmaps[$i]=$monitor->{'warning_bitmap'} if $opt_b;
    }
    $n += $stamon->n_suspend;
    for (; $i < $n; $i++) {
        $colors[$i]=$monitor->{'suspended_color'}; 
        $bitmaps[$i]=$monitor->{'suspended_bitmap'} if $opt_b;
    }
    $n += $stamon->n_run;
    for (; $i < $n; $i++) {
        $colors[$i]=$monitor->{'running_color'}; 
        $bitmaps[$i]=$monitor->{'running_bitmap'} if $opt_b;
    }
    $n += $stamon->n_pend;
    for (; $i < $n; $i++) {
        $colors[$i]=$monitor->{'pending_color'}; 
        $bitmaps[$i]=$monitor->{'pending_bitmap'} if $opt_b;
    }

    my $nmax = $monitor->{'max_blocks'};
    $nmax = $n if ($n < $nmax);
    for ($i = 0; $i < $nmax; $i++) {
        if ($buttons[$i]->cget(-state) eq 'active') {
            you_are_here($buttons[$i], $stamon, $i);
            last;
        }
    }

    my $max_blocks = $n - $start;
    # Handle the case of going off the end
    if ($max_blocks > $monitor->{'max_blocks'}) {
        $max_blocks = $monitor->{'max_blocks'};
        $buttons[$max_blocks-1]->configure(-text => '>') if (! $opt_b);
        $buttons[$max_blocks-1]->configure(-command =>[\&scroll_job, $stamon, $monitor, 1]);
    }
    elsif ($max_blocks) {
        my $last_block = $monitor->{'max_blocks'} - 1;
        $buttons[$last_block]->configure(-text => ' ') if (! $opt_b);
        $buttons[$last_block]->configure(-command =>[\&drill_down, $stamon, $last_block]);
    }
    if ($start) {
        $buttons[0]->configure(-text => '<') if (! $opt_b);
        $buttons[0]->configure(-command =>[\&scroll_job, $stamon, $monitor, -1]);
    }
    else {
        $buttons[0]->configure(-text => ' ') if (! $opt_b);
        $buttons[0]->configure(-command =>undef);
        $buttons[0]->configure(
            -command =>[\&drill_down, $stamon, 0]);
    }

    # Update the colors and bitmaps of all the buttons
    my $j;
    for ($i = 0, $j = $start; $i < $max_blocks; $i++, $j++) {
        if ($ra_prev_colors->[$i] ne $colors[$j]) {
            $buttons[$i]->configure( -bg=>$colors[$j], -bitmap=>$bitmaps[$j]);
            $ra_prev_colors->[$i] = $colors[$j];
        }
    }

    # Fill in the empty ones on the end
    for ($i = $max_blocks; $i < ($n_buttons - 2); $i++) {
        if ($ra_prev_colors->[$i] ne $monitor->{'empty_color'}) {
            $buttons[$i]->configure(-bg=>$monitor->{'empty_color'},
                -bitmap=>($opt_b ? $monitor->{'empty_bitmap'} : undef));
            $ra_prev_colors->[$i] = $monitor->{'empty_color'};
        }
    }

    # Update the text of the Success and Failed labels
    $buttons[$n_buttons-2]->configure(-text => sprintf "%d", 
        $stamon->success_count);
    $buttons[$n_buttons-1]->configure(-text => sprintf "%d", 
        $stamon->failure_count);
    $buttons[$n_buttons-4]->configure(-text => sprintf "%d", 
        $stamon->n_pend);
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
    my ($parent, $monitor) = @_;
    my $frame = $parent->Frame();
    $parent->Button(-text=>'Refresh', -command=>[\&reconfigure, $monitor])->pack(-side=>'left');

# Add in other user buttons
my $count = 0;
foreach my $key ( sort { $a <=> $b } keys %CFG::tkstat_commands ) {
    $count++;
    if ( $count > 6 ) {
        warn "Too many user-defined buttons configured. Only first 6 will be added.\n\n";
        last;
    }
    my $label = $key;
    $label =~ s/^[0-9]+://;
# If the word 'kill' is used, make it stand out in red
    if ( $label =~ /kill/i ) {
        $parent->Button(-text=>"$label",
            -foreground => 'red', -command=>sub{
              my $cmd = $CFG::tkstat_commands{$key};
              my $cwd = getcwd();
              chdir($cfgdir) or warn "Cannot chdir to $cfgdir: $!";
              my ($errstr, $rc) = S4P::exec_system("$cmd");
              chdir($cwd) or warn "Cannot chdir back to $cwd: $!";
              if ($rc) {
                  warn "$errstr\n\n";
              }
           })->pack(-side=>'left');
    } else {
        $parent->Button(-text=>"$label", -command=>sub{
            my $cmd = $CFG::tkstat_commands{$key};
            my ($errstr, $rc) = S4P::exec_system("$cmd");
            if ($rc) {
                warn "$errstr\n\n";
            }
        })->pack(-side=>'left');
    }
}
    $parent->Button(-text=>'Exit', -command=>sub{exit 0})->pack(-side=>'right');
    $frame->pack(-fill=>'x',-anchor=>'e');
    return $frame;
}
###########################################################################
# show_station_status($stamon, $button, $down_color, $warning_color, $pending_color)
# $stamon - which directory to check
# $button - button to be reconfigured accordingly
# $down_color - background color to use if station is down
# $warning_color - background color to use if station is in trouble 
#    failed_children >= max_failures
# -------------------------------------------------------------------------
# Check station status and change the button color appropriately
###########################################################################
sub show_station_status {
    use strict;
    my ($stamon, $button, $down_color, $warning_color, $pending_color) = @_;

    # Set normal/disabled status
    $button->configure(-state => (($opt_R || $stamon->disable) ? 'disabled' : 'normal'));

    my $background = $button->cget(-highlightbackground);
    if (! $stamon->station_status) {
        $button->configure(-bg => $down_color, -fg => 'white', 
            -activeforeground => $down_color);
    }
    elsif ($stamon->anomalies) {
        $button->configure(-bg => $warning_color, -fg => 'black', 
            -activeforeground => 'black');
    }
    elsif ($stamon->got_hold) {
        $button->configure(-bg => $pending_color, -fg => 'white', 
            -activeforeground => 'black');
    }
    else {
        $button->configure(-bg => $background, -fg => 'black', 
            -activeforeground => 'black');
    }
}
###########################################################################
# you_are_here ($station, $job_number)
#   $station - which station we're mousing over
#   $job_number - which index in the job row we're mousing over
# -------------------------------------------------------------------------
# Show the job underneath when user mouses over job box
###########################################################################
sub you_are_here {
    my ($button, $stamon, $job_number) = @_;
    if ($stamon) {
        my $job = get_job($stamon, $job_number);
        # Look for one-line job.message file in directory
        my $file = sprintf("%s/%s/job.message", $stamon->dir, $job);
        if (-e $file) {
            open MESSAGE, $file;
            my $text = <MESSAGE>;
            close MESSAGE;
            chomp($text);
            $you_are_here = "$job: $text";
        }
        else {
            $you_are_here = $job;
        }
        $balloon->attach($button, -msg => $you_are_here);
    }
    else {
        $you_are_here = ' ';
    }
}
sub get_job {
    my ($stamon, $job_number) = @_;
    $job_number += $start_button{$stamon};
    return '' if ($job_number >= $stamon->n_jobs);
    my @sort_index = sort {
       ( ($stamon->status($a) cmp $stamon->status($b)) ||
         ($stamon->jobs($a) cmp $stamon->jobs($b)) )
    } (0..($stamon->n_jobs - 1));
    return $stamon->jobs($sort_index[$job_number]);
}
###########################################################################
# scroll_job($stamon, $monitor, $jump)
#   $stamon - station row to scroll
#   $monitor - monitor object: used to pass on to update_buttons
#   $jump - how many boxes to scroll (and which direction)
# -------------------------------------------------------------------------
# Scroll job row back and forth
###########################################################################
sub scroll_job {
    my ($stamon, $monitor, $jump) = @_;
    $start_button{$stamon} += $jump;
    $start_button{$stamon} = 0 if ($start_button{$stamon} < 0);
    update_buttons($stamon, $monitor, $start_button{$stamon},
        $station_buttons{$stamon}, \@{$prev_colors{$stamon}});
}
sub popup_menu {
    my ($widget, $menu, $station) = @_;
    return 0 if ($station->disable || $opt_R);
    my $dir = $station->dir;
    my $umask = $station->set_umask;
    my ($x,$y) = $widget->pointerxy;
    # Activate/deactivate buttons if station is down
    # In single-user mode, we have 3 buttons: Stop, Stop Fast and Start
    # If multi-user mode, we have 2 buttons:  Start and Stop
    if (S4P::check_station($dir)) {
        # Stop gently stops station with work order
        $menu->entryconfigure(1, -label => 'Stop', -command => [\&stop_station, $dir, 'gently', $umask]);
        $menu->entryconfigure(2, -state=>'normal');
        $menu->entryconfigure(3, -state=>'normal') 
            if (popup_menu_has_stop_fast($station));
    }
    else {
        $menu->entryconfigure(1, -label => 'Start',
            -command => [\&S4P::TkJob::start_station, $opt_C, $dir]);
        $menu->entryconfigure(2, -state=>'disabled');
        $menu->entryconfigure(3, -state=>'disabled')
            if (popup_menu_has_stop_fast($station));
    }
    $menu->post($x, $y);
}
sub stop_station {
    my $dir = shift;
    my $options = shift;
    my $umask = shift;

    my $thisdir = cwd();
    if (! chdir $dir) {
        S4P::logger('ERROR', "Cannot chdir to $dir: $!");
        return 0;
    }
    if ($options) {
        # Set umask if we are writing a file
        umask($umask) if $umask;
        S4P::stop_station($options);
    }
    else {
        S4P::stop_station();
    }

    refresh($monitor) unless $options;
    if (! chdir $dir) {
        S4P::perish(2, "Cannot chdir to $dir: $!");
        return 0;
    }
}

sub create_menu {
    my ($parent, $stamon) = @_;
    my $dir = $stamon->dir;
    my $umask = $stamon->set_umask;
    # There must be a good reason we re-read this menu, but I don't recall it...-CSL
    %CFG::cfg_interfaces = ();
    my $cpt = Safe->new('MENU');
    $cpt->share('%cfg_interfaces');
    if (! $cpt->rdo("$dir/station.cfg")) {
        warn "Cannot parse $dir/station.cfg";
        return;
    }
    my %interfaces = %MENU::cfg_interfaces;
    my $menu = $parent->Menu;
    # Button order:
    #    Start / Stop
    #    Stop Fast
    #    Restart
    #    [Station-specific buttons]
    $menu->command(-label => 'Start/Stop', "-command" => [\&stop_station, $dir, 'gently']);

### A 'Stop Fast' is dangerous when $cfg_max_children is set to zero:
### Also, we are disabling Stop Fast in multi-user mode, as indicated
### by $cfg_group

    $menu->command(-label => 'Stop Fast', "-command" => [\&stop_station, $dir])
        if (popup_menu_has_stop_fast ($stamon));

    $menu->command(-label => 'Restart Station', "-command" => [\&stop_station, $dir, 'restart', $umask]);
    my $name;
    foreach $name (keys %interfaces) {
        $menu->command(-label => $name, 
            "-command" => [\&run_command, $dir, $interfaces{$name}, $umask]);
    }
    return $menu;
}
sub popup_menu_has_stop_fast { 
    my $stamon = shift;
    return !($stamon->group || $stamon->max_children == 0);
}
sub run_command {
    my ($dir, $command, $umask) = @_;
    my $thisdir = cwd();
    umask($umask) if $umask;
    if (! chdir $dir) {
        S4P::logger('ERROR', "Cannot chdir to $dir: $!");
        return 0;
    }
    S4P::fork_command($command);
    if (! chdir $thisdir) {
        S4P::perish(2, "Cannot return to $thisdir: $!");
        return 0;
    }
    return 1;
}

sub filter_disabled {
    my @stamon = @_;
    my @filtered = ();
    foreach my $s ( @stamon ) {
        unless ( $s->disable ) { push(@filtered, $s); }
    }
    return @filtered;
}

