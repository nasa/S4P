#!/usr/bin/perl

=head1 NAME

tkexec - execute command from Tk window

=head1 SYNOPSIS

tkexec.pl
[B<-m> I<message>]
[B<-r>]
command arg arg ...

=head1 DESCRIPTION

GUI wrapper around simple command line executables.
This supplies a confirmation message and a response.

=head1 ARGUMENTS

=over 4

=item [B<-m> I<message>]

Confirmation message.  Default is "Do you want to run [command]?".

=item [B<-r>]

Repeat, i.e., keep the interface up for repetitive invokations.

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# tkexec.pl,v 1.2 2006/09/12 19:43:50 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use Getopt::Std;
use strict;
use vars qw($opt_m $opt_r);
use Tk;
use S4P::S4PTk;

getopts('m:r');

my $message = $opt_m || join(' ', "Do you want to run", @ARGV, "?");
my $main_window = new MainWindow;
$main_window->Label(-text => $message)->pack(-side=>'top');
$main_window->Button(-text => 'OK',
    -command => [\&do_it, $main_window, $opt_r, @ARGV])->pack(-side=>'left');
$main_window->Button(-text => 'Exit', -command=>sub{exit 0})->pack(-side=>'right');
MainLoop();

sub do_it {
    my $mw = shift;
    my $repeat = shift;
    my @cmd = @_;
    my ($rs, $rc) = S4P::exec_system(@cmd);
    my $dialog_msg = $rs ? $rs : "Job successful.";
    my $dialog = $mw->DialogBox(
        -title => "tkexec: $cmd[0]",
        -buttons => ['OK']);
    $dialog->add('Label', -text => $dialog_msg, -wraplength => 350)->
        pack(-side => 'left', -expand => 1);
    $dialog->Show();
    exit($rc) unless $repeat;
}
