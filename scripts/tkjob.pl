#!/usr/bin/perl

=head1 NAME

tkjob - view what's going on in an S4P job

=head1 SYNOPSIS

tkjob [B<-f> I<font>] [job_dir]

=head1 DESCRIPTION

This is not usually called in isolation, but rather forked off from
tkstations.pl.  In this incarnation, it displays the various files in a job 
directory, allowing the user to view them.

However, it can be called on its own, as a simple file/directory browser.
In this incarnation, the user can also double click on a directory to drill 
down a level.

It displays the files in a directory in an upper list box.  For a station, this
will show you which jobs are running and which are failed, each of which has
its own directory.  By double-clicking on the directory, you can drill down
into it for more info on the files.

The bottom box displays the contents of the file that is currently selected in
the top list box.  This allows you to view the configuration files, log files, 
etc.  It also has the capability to display the contents of simple dbm files.

=head1 ARGUMENTS

=over 4

=item B<-f> I<font>

Set the font for the whole interface.
B<N.B.: Make sure to quote it if the font begins with a hyphen, as most do.>

=back

=head1 FILES

=over 4

=item station.cfg

The station configuration file is read when in a station directory or its job
subdirectory.  It is used to locate station-specific interfaces or failure
handlers, %cfg_interfaces and %cfg_failure_handlers respectively.  
These are hashes where the key is a button label and the value is the command
to be executed when the button is pressed.

The %cfg_interfaces buttons are available only in the Station directory.
The %cfg_failure_handlers buttons are available only in a I<failed> job
directory.

=back

=head1 SEE ALSO

Monitor(3), tkstations(1)

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# tkjob.pl,v 1.2 2006/09/12 19:43:50 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use Tk;
use S4P::TkJob;
use strict;
use Cwd;

use vars qw($opt_d);

my $dir = $ARGV[0] || cwd();

# Main Window
my $tkjob = new S4P::TkJob(undef, $dir) or die "Cannot create TkJob for $dir";
MainLoop();
exit(0);
