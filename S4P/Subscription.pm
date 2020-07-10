=head1 NAME

S4P::Subscription - simple subscription fulfillment for online data

=head1 SYNOPSIS

use S4P::Subscription;

S4P::Subscription::fill_subscriptions($config_file, $pdr, $verbose);

=head1 DESCRIPTION

The S4P::Subscription module satisfies basic subscriptions for online 
data.  That is, it sends email to the users to let them know that the
data is available for download.  It does have the flexibility for each
user to have an arbitrary "match" script check the subscription.

=head2 fill_subscriptions

This is the main driver routine, taking simply a configuration filename
with the subscriptions in it, a PDR with the files to be evaluated, and
a verbose flag.

=head1 FILES

The configuration file consists of Perl variables:

=over 4

=item %cfg_url

This is the pattern for forming a URL.  It is based on strftime-style 
date/time formats, with extensions for other elements like data type,
version and filename.  The currently supported patterns are:

         %Y:   four-digit year
         %m:   two-digit month (01-12)
         %d:   two-digit day of month (01-31)
         %u:   three-digit day of year (01-366)
         %=T:  data type (dataset name)
         %=V:  three-digit data version (001-999)
         %=F:  filename

For example, a Data Pool url for a MOD02SSH granule would look like this:

    ftp://g0dps01u.ecs.nasa.gov/MOGT/%=T.%=V/%Y.%m.%d/%=F

=item %cfg_subscriptions

This is a complex hash, keyed on a concatenated string datatype and version
("datatype.version", e.g. MOD021KM.004).
The second key is the email address of the subscriber.
The value is an anonymous array of "match" script commands.
These commands are executed by appending the data files and metadata
file for a given granule (FILE_GROUP in the PDR).
For example:

  %cfg_subscriptions = (
      'MOD02SSH.004' => {
          'Christopher.S.Lynnes@nasa.gov' => ['true', 'false']
      },
  );

=back

=head1 AUTHOR

Christopher Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# Subscription.pm,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P::Subscription;
use File::Basename;
use S4P;
use S4P::MetFile;
use S4P::TimeTools;
use strict;
use Safe;
1;
#=====================================================================
sub expand_url {
    my ($data_url_root, $metadata_url_root, $data_type, $data_version, 
        $met_file, @science_files) = @_;
    my $esdt = $data_type;
    my $vvv = sprintf("%03d", $data_version);

    # Get datetime from .met (or .xml) file
    my $datetime;
    if ($met_file) {
        unless (-f $met_file) {
            S4P::logger('ERROR', "$met_file does not exist");
            return;
        }
        $datetime=S4P::MetFile::get_start_datetime($met_file);
    }
    my ($yyyy, $mm, $dd) = ($datetime =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/);
    my $doy = sprintf("%03d", S4P::TimeTools::day_of_year($yyyy, $mm, $dd));

    # Got all of the components: now plug 'em in
    my @urls;
    $data_url_root =~ s/%=T/$data_type/;
    $data_url_root =~ s/%=V/$data_version/;
    $metadata_url_root =~ s/%=T/$data_type/;
    $metadata_url_root =~ s/%=V/$data_version/;

    # Date follows strftime conventions
    $data_url_root =~ s/%Y/$yyyy/;
    $data_url_root =~ s/%m/$mm/;
    $data_url_root =~ s/%d/$dd/;
    $data_url_root =~ s/%j/$doy/;
    $metadata_url_root =~ s/%Y/$yyyy/;
    $metadata_url_root =~ s/%m/$mm/;
    $metadata_url_root =~ s/%d/$dd/;
    $metadata_url_root =~ s/%j/$doy/;

    # Put metadata_file on first
    $met_file = basename($met_file);
    $metadata_url_root =~ s/%=F/$met_file/;
    push @urls, $metadata_url_root;

    # Loop through all data files in granule
    foreach my $science_file(@science_files) {
        my $url = $data_url_root;
        my $file = basename($science_file);
        $url =~ s/%=F/$file/;
        push @urls, $url;
    }
    return @urls;
};
#=====================================================================
sub fill_subscriptions {
    my ($cfg_file, $pdr, $verbose) = @_;

    # Read config file
    my ($rh_cfg_url, $rh_cfg_subscriptions) = 
        read_config_file($cfg_file) or return 0;

    # Look for subscription matches
    # %match = ($email => [url, url, url...])
    my $match = match_subscriptions($pdr, $rh_cfg_url, $rh_cfg_subscriptions) 
        or return 0;

    # Mail out the notifications
    mail_notifications($match, $verbose);

    return 1;
}
#=====================================================================
sub mail_notifications {
    my ($rh_match, $verbose) = @_;

    my $subject = "New data available online";
    my $header = "New data and metadata files are now available online at the URLs:";
    # key is email address
    foreach my $email(keys %$rh_match) {
        my $text = join("\n", $header, @{$rh_match->{$email}});
        my $cmd = "Mail -s '$subject' '$email'";
        if (! open MAIL, "|$cmd") {
            S4P::logger('ERROR', "Cannot open pipe to command '$cmd'");
            return 0;
        }
        print MAIL $text;
        if (!close MAIL) {
            S4P::logger('ERROR', "Cannot close pipe for command '$cmd'");
            return 0;
        }
    }
    return 1;
}

#=====================================================================
sub match_subscriptions {
    my ($pdr, $rh_url, $rh_subscriptions, $verbose) = @_;

    # Get FILE_GROUPS from PDR
    my @file_groups = @{$pdr->file_groups};
    unless (@file_groups) {
        S4P::logger('ERROR', "No FILE_GROUPS in PDR");
        return;
    }

    # Foreach granule (FILE_GROUP), check for matches
    my $match = {};
    foreach my $file_group(@file_groups) {
        # Concatenate data_type and Data_version into data_type_version
        my $data_type = $file_group->data_type;
        my $data_version = $file_group->data_version;        
        
        
        my ( $url_pattern,
             $subscription ) = get_subscription_info( $data_type, $data_version,
                                                      $rh_url,
                                                      $rh_subscriptions );
        
        next unless $url_pattern;
        next unless $subscription;        
        
        # Get data files and metadata file
        my @science_files = $file_group->science_files();
        my $met_file = $file_group->met_file();

        # Currently assume that URL pattern is the same for data & metadata
        my @urls = expand_url($url_pattern, $url_pattern, $data_type, 
                              $data_version, $met_file, @science_files);

        foreach my $email ( keys %$subscription ) {
            foreach my $exec ( @{$subscription->{$email}} ) {
                my $cmd = join( ' ', $exec, @science_files, $met_file );
                S4P::logger('INFO', "Subscription script call: $cmd") if $verbose;
                my ($errstr, $rc) = S4P::exec_system($cmd);
                if ($rc == 0) {
                    push @{$match->{$email}}, @urls;
                } elsif ($rc > 255) {
                    S4P::logger('ERROR', "Failed to execute match command $cmd");
                    return;
                } elsif ($verbose) {
                    S4P::logger('INFO', "No match for $email / $science_files[0]");
                }
            }
        }
    }
    return $match;
}
#=====================================================================
sub read_config_file {
    my ($cfg_file) = shift;

    # Setup compartment and read config file
    my $cpt = new Safe('CFG');
    $cpt->share('%cfg_url', '%cfg_subscriptions');

    # Read config file
    if (! $cpt->rdo($cfg_file)) {
        S4P::logger('ERROR', "Cannot read config file $cfg_file");
    }
    # Check for required variables
    elsif (! %CFG::cfg_url) {
        S4P::logger('ERROR', "No %cfg_url in $cfg_file");
    }
    elsif (! %CFG::cfg_subscriptions) {
        S4P::logger('ERROR', "No %cfg_subscriptions in $cfg_file");
    }
    else {
        return (\%CFG::cfg_url, \%CFG::cfg_subscriptions);
    }
    return;    # If we got here, there must have been an error above
}
#=====================================================================
sub get_subscription_info
{
    my ( $data_type, $data_version, $rh_url, $rh_subscriptions ) = @_;
    
    my ( $url_pattern, $subscription );
    my $version_string = sprintf( "%s.%s", $data_type, $data_version );
    
    if ( defined $rh_url->{$version_string} ) {
        $url_pattern = $rh_url->{$version_string};
    } else {
        foreach my $key ( sort keys %$rh_url ) {
            next unless ( $key =~ /^$data_type\.(.+)/ );
            my $version = qr($1);
            next unless ( $data_version =~ m{$version} );
            $url_pattern = $rh_url->{$key};
            last;
        }
    }
    
    if ( defined $rh_subscriptions->{$version_string} ) {
        $subscription = $rh_subscriptions->{$version_string};
    } else {
        foreach my $key ( sort keys %$rh_subscriptions ) {
            next unless ( $key =~ /^$data_type\.(.+)/ );
            my $version = qr($1);
            next unless ( $data_version =~ m{$version} );
            $subscription = $rh_subscriptions->{$key};
            last;
        }    
    }
    
    return ( $url_pattern, $subscription );
}
