=head1 NAME

S4PTk - Tk-related routines for use by S4P GUIs

=head1 SYNOPSIS

use S4P::S4PTk;

S4P::S4PTk::redirect_logger($main_window);

$answer = S4P::S4PTk::confirm($main_window, $message);

S4P::S4PTk::read_options($widget)

=head1 DESCRIPTION

These are common utility routines for use by S4P GUIs.

=over 4

=item redirect_logger($main_window)

This routine "redirects" S4P::logger messages to a Perl/Tk popup window
(for use by Perl/Tk programs).
After calling this, you need only call S4P::logger to display error, warning,
or info messages to the user.  Only an "OK" button will appear; you cannot get
input or feedback this way.

=item confirm($main_window, $message)

This pops up a confirmation dialog box with the message, an OK button and a
Cancel button.  It returns 1 if the OK button was pressed and 0 otherwise.

=item read_options($widget)

This reads the .Xdefaults and/or .Xresources file in the user's home directory
if either exists. This allows specification of widget properties in .Xdefaults,
which Perl/Tk otherwise (appears to) ignore.

=back

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# S4PTk.pm,v 1.6 2008/03/11 19:01:16 lynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P::S4PTk;
use Tk;
use Tk::DialogBox;
use Tk::ROText;
use S4P;
1;

##########################################################################
# redirect_logger($main_window)
#   $main_window - toplevel main window of a Perl/Tk application
#-------------------------------------------------------------------------
# Redirect_logger sets up to redirect all calls to S4P::logger to go to
# a Perl::Tk popup window.
##########################################################################

sub redirect_logger {
    use strict;
    my $main_window = shift;
    # Generate a magical closure with the same argument list as S4P::logger
    # is expecting
    S4P::redirect_log(
        sub {
            my ($timestamp, $pid, $login, $severity, $app, $message) = @_;
            my $dialog_msg = sprintf ("%s: %s", $severity, $message);
            my $dialog = S4P::S4PTk::scrolled_dialog($main_window, 
                "$app: $severity", $dialog_msg, ['OK']);
            $dialog->Show();
        }
    );
}
sub confirm {
    my ($main_window, $msg) = @_;

    # Create scrolled text dialog
    my $dialog = scrolled_dialog($main_window, "Confirm?", $msg, 
        ['OK', 'Cancel']);
    # The answer is the text of the box that was clicked.
    my $answer = $dialog->Show();

    # Compare answer with 'OK' and return
    return ($answer eq 'OK');
}
# Creates a scrolled ROText for DialogBoxes
sub scrolled_dialog {
    my ($main_window, $title, $message, $ra_buttons) = @_;
    my $dialog = $main_window->DialogBox(
        -title => $title, -buttons => $ra_buttons);
    # Add a frame so we can get a handle to hang our Scrolled(ROText) on
    my $frame = $dialog->add('Frame')->pack(-side => 'left', -expand => 1);
    my $t = $frame->Scrolled('ROText', -relief=>'flat', 
        -scrollbars=>'ose', -height=>10, -wrap=>'word')->
        pack(-expand=>1, -fill=>'both');
    $t->insert('end', $message);
    return $dialog;
}
##########################################################################
# read_options($widget)
#   $widget - usually, toplevel main window of a Perl/Tk application
#-------------------------------------------------------------------------
# This reads the .Xdefaults and .Xresources files if they exist.
# Otherwise Perl/Tk (appears to) ignore any such settings.
##########################################################################
sub read_options {
    my $widget = shift;
    my $home = $ENV{'HOME'} || (getpwuid($<))[7] || return 0;
    my $file;
    foreach $file ('.Xdefaults', '.Xresources') {
        $widget->optionReadfile("$home/$file") if (-f "$home/$file");
    }
}
