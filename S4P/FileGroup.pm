=head1 NAME

S4P::FileGroup.pm - Perl module implementing FILE_SPEC object of a PDR

=head1 SYNOPSIS

=for roff
.nf

use S4P::FileGroup;
$fg  = new S4P::FileGroup('text'=>$text);

$fg->data_type($data_type); 
$data_type = $fg->data_type;

$fg->data_version($data_version,[$format]); 
$data_version  = $fg->data_version;

$fg->node_name($node_name); 
$node_name  = $fg->node_name;

$fg->file_specs(\@file_specs); 
@file_specs  = @{$fg->file_specs};

%files_sizes  = $fg->load_sizes();
%files_dirs  = $fg->load_dirs();

$metfile = $fg->met_file(); 

$browsefile = $fg->browse_file();

$qafile = $fg->qa_file();

$mapfile = $fg->map_file();

@files = $fg->science_files();

@files = $fg->data_files();

$fg->checksum();

$fg->verify_checksums();

$fg->sprint([$spacious]);

=head2 Alternate attributes added for S4PM

$fg->ur($ur);
$ur = $fg->ur;

$fg->local_granule_id($local_granule_id);
$ur = $fg->local_granule_id;

$fg->lun($lun);
$lun = $fg->lun;

$fg->data_start($data_start);
$data_start = $fg->data_start;

$fg->data_end($data_end);
$data_end = $fg->data_end;

$fg->need($need);
$need = $fg->need;

$fg->timer($timer);
$timer = $fg->timer;

$fg->currency($currency);
$currency = $fg->currency;

$fg->boundary($boundary);
$boundary = $fg->boundary;

$fg->status($status);
$status = $fg->status;

$fg->copy_status($localhost, $local_dir);
$copy_status = $fg->copy_status;

$ftp = $fg->ftp_get($remote_host, $local_dir, $ftp, $max_attempts, $snooze);

fg->http_get($local_dir);

$status = $fg->ssh_get( $remote_host, $local_dir );

$new_fg = $fg->symlinks($local_dir);

$protocol = $fg->protocol();
$fg->protocol( $protocol );

$statuss = $fg->bbftp_get($remote_host, $local_dir, $bbftp, $max_attempts, $snooze);

=head1 DESCRIPTION

FileGroup.pm implements a FILE_GROUP object of a Product Delivery
Record (PDR).  A FILE_GROUP is a group of related files--Science, 
metadata, product history and browse--that make up a granule.  
The individual files in the FILE_GROUP are implemented as FILE_SPECs.

The standard attributes are data_type, data_version, node_name and file_specs.
The last is a reference to an array of FileSpec objects.
The data_type is generally an ECS ESDT short name, while data_version
is the ESDT version_id, which is an integer between 0 and 255.
The node_name is the Internet node where the data reside.

In addition, a number of attributes have been added to support other uses of
the FILE_GROUP object, which give more information about the "granule" in the
FILE_GROUP, be it actual or desired (as in requests).
These include the following:

=over 4

=item ur

ECS Universal reference.

=item local_granule_id

Local granule id (i.e. that used by a non-ECS system)

=item data_start

Beginning of the data time range, YYYY-MM-DDTHH:MM:SS.SSSSZ

=item data_end

End of the data time range, YYYY-MM-DDTHH:MM:SS.SSSSZ

=item timer

Used in requests, the amount of time (in seconds) to wait for the data.

=item need

Used in requests, whether the granule is required (REQ), or optional (OPT) and
if so, which option it is (OPT1, OPT2, etc.)

=item currency

Describes how contemperaneous the data type requested is with the
processing period. Possible values are:

CURR = input contemperaneous with the PGE processing period

PREVn = input is n steps previous to the PGE processing period (by
increments equal to the temporal coverage of the input itself). 
PREV1 means the previous granule, PREV2 means the granule before that, etc.

FOLLn = input is n steps following the PGE processing period (by increments
equal to the temporal coverage of the input itself). A FOLL1 means the 
following granule, a FOLL2 means the granule follwing that, etc.

=item boundary

Time boundary against which to determine start times of input granules.
Valids are START_OF_DAY, START_OF_HOUR, START_OF_WEEK and START_OF_6HOUR. 

=item status

Status of granule.  This is useful for maintaining success/failure information
as a PDR moves through the work stations.

=item met_file

Returns the pathname corresponding to the METADATA-type file in the FILE_GROUP.

=item browse_file

Returns the pathname corresponding to the BROWSE-type file in the FILE_GROUP.

=item qa_file

Returns the pathname corresponding to the QA-type file in the FILE_GROUP.

=item map_file

Returns the pathname corresponding to the HDF4MAP-type file in the FILE_GROUP.

=item science_files

Returns an array of pathnames corresponding to the SCIENCE-type files in
the FILE_GROUP.

=item data_files

Returns an array of pathnames corresponding to the non-METADATA type files
in the FILE_GROUP.

=item checksum

Computes checksum (S4P::FileSpec::checksum) for just the SCIENCE files
in a science group.

=item verify_checksums

Verifies checksums (S4P::FileSpec::verify_checksum) for the SCIENCE files
in a science group and compares against the current values.

=item sprint([$spacious]);

Prints out FILE_GROUP in ODL format to a string (most often used by 
PDR::sprint). The $spacious argument specifies whether '=' signs are set off by
spaces or not. Default is not, but interfaces such as EPD prefer the spacious
variety.

=item file_get

This copys the data to a local directory using File::Copy::copy.

=item http_get

This transfers the data to a local directory using HTTP.
If the NODE_NAME in the FILE_GROUP is of the form name:alias, it will look
up the alias in the .netrc file to get a username and password.

=item ftp_get

This transfers the data to a local directory using FTP.
Note that this requires a .netrc file. It returns a Net::FTP object for
persistent connection.
Set shell environment variable $FTP_FIREWALL be the firewall server
to enable FTP through firewall.

=item ssh_get

This transfers the data to a local directory using SFTP. Note that this requires
a .netrc file entry for the host being connected to and publich/private keys for
object for persistent connection. For special option on sftp command, either set
up an alias or set up ~/.ssh/config for ssh connection option. 

=item bbftp_get

This transfers the data to a local directory using BBFTP. Note that this requires
a .netrc file entry for the host being connected to and publich/private keys for
object for persistent connection.

=item symlinks

This method creates symlinks in a local directory that point to the
files in the FILE_GROUP.  It returns a new FILE_GROUP object with the
new directory.

=item download

This is a wrapper for ftp_get() and ssh_get(). Calls appropriate method based on
the protocol of file group.

=item protocol

Supplied an argument, this sets the file group's protocol to be used in file transfer.
Otherwise, returns the current value. Valids are 'FILE', 'FTP' and 'SFTP'.

=back

=head1 TO DO

Check to see that object is a FILE_GROUP
Error handling for garbled FILE_GROUP (missing attributes)

=head1 SEE ALSO

FileSpec(3), PDR(3)

=head1 AUTHORS

Chris Lynnes, NASA/GSFC, Code 610.2
Daniel Ziskin, George Mason University

=cut

################################################################################
# FileGroup.pm,v 1.25 2011/05/31 18:43:13 glei Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use Net::Netrc;

package S4P::FileGroup;
    use S4P::FileSpec;
    use S4P::Connection;
    use File::Basename;
    use File::Copy();  # Prevent warnings about copy() redefined

    # The first three are standard for SIPS
    my @ecs_attributes = ('data_type', 'data_version', 'node_name');
    my @s4p_attributes = ('ur', 'local_granule_id', 'need', 'lun',
        'data_start', 'data_end', 'timer','currency','boundary','status');
    my @attributes;
    push @attributes, @ecs_attributes, @s4p_attributes;
    1;

sub new {
    use strict;
    my $pkg = shift;
    my %params = @_;

    my $file_spec;

    # If text is set, parse it for a FILE_GROUP structure
    if ($params{'text'}) {
        my $text = $params{'text'};
        # Check for basic syntax
        return undef unless ($text =~ /OBJECT\s*=\s*FILE_GROUP;.*END_OBJECT\s*=\s*FILE_GROUP;/s);
        # Parse FILE_GROUP-level attributes
        foreach my $attr(@attributes) {
            if ($text =~ /$attr\s*=\s*(.*?);/i) { 
                $params{$attr} = $1;
            }
        }
        my @file_specs;
        # Parse FILE_SPECs by instantiating new S4P::FileSpec objects
        while ($text =~ m/(OBJECT\s*=\s*FILE_SPEC;.*?END_OBJECT\s*=\s*FILE_SPEC;)/gs) {
            $file_spec = S4P::FileSpec->new('text'=>$1);
            return undef if (! $file_spec);  # Parsing failure
            push @file_specs, $file_spec;
        }
        $params{'file_specs'} = \@file_specs;
    }
    my $r_filegroup = \%params;
    bless $r_filegroup, $pkg;
    return $r_filegroup;
}
sub copy {
    my $this = shift;
    my $new_fg = new S4P::FileGroup;
    my @file_specs;
    map { $new_fg->{$_} = $this->{$_} } @attributes;
    map { push @file_specs, $_->copy } @{ $this->file_specs };
    $new_fg->file_specs(\@file_specs);
    return $new_fg;
}

# Attribute get/set routines
sub data_type        {my $this = shift; @_ ? $this->{'data_type'} = shift
                                           : $this->{'data_type'}}
# Following ECS-SIPS ICD, data_version must be a three-digit integer
#sub data_version     {my $this = shift;  my ($version, $format ) = @_;
#                         $format = "%03d" unless defined $format;
#                         (defined $version) ? $this->{'data_version'} = sprintf($format, $version)
#                            : $this->{'data_version'}}
sub data_version {
    my $this = shift;
    my ($version, $format) = @_;
    if ( $ENV{'S4P_LEGACY_DATAVERSION'} ) {
        if ( defined $version ) {             # We want to set the version
            if ( defined $format ) {
                $this->{'data_version'} = sprintf($format, $version);
            } else {
                if ( $version =~ /^[0-9]+$/ ) {
                    $this->{'data_version'} = sprintf("%03d", $version);
                } else {
                    $this->{'data_version'} = sprintf("%s", $version);
                }
            }
        } else {                      # We just want to retrieve the version
            my $ver = $this->{'data_version'};
            if ( $ver =~ /^[0-9]+$/ ) {
                return sprintf("%03d", $ver);
            } else {
                return $ver;
            }
        }
    } else {
        if ( defined $version ) {             # We want to set the version
            $format = "%s" unless defined $format;
            $this->{'data_version'} = sprintf($format, $version);
        } else {
            return $this->{'data_version'};
        }
    }

}
sub node_name        {my $this = shift; @_ ? $this->{'node_name'} = shift
                                           : $this->{'node_name'}}
sub file_specs       {my $this = shift; @_ ? $this->{'file_specs'} = shift
                                           : $this->{'file_specs'}}

# Alternate attributes for S4PM
sub ur               {my $this = shift; @_ ? $this->{'ur'} = shift
                                           : $this->{'ur'}}
sub lun              {my $this = shift; @_ ? $this->{'lun'} = shift
                                           : $this->{'lun'}}
# Note that timer could be set to 0
sub timer            {my $this = shift; (defined($_[0])) 
                                           ? $this->{'timer'} = shift 
                                           : $this->{'timer'}}
sub need             {my $this = shift; @_ ? $this->{'need'} = shift
                                           : $this->{'need'}}
sub data_start       {my $this = shift; @_ ? $this->{'data_start'} = shift
                                           : $this->{'data_start'}}
sub data_end         {my $this = shift; @_ ? $this->{'data_end'} = shift
                                           : $this->{'data_end'}}
sub currency         {my $this = shift; @_ ? $this->{'currency'} = shift
                                           : $this->{'currency'}}
sub boundary         {my $this = shift; @_ ? $this->{'boundary'} = shift
                                           : $this->{'boundary'}}
sub local_granule_id {my $this = shift; @_ ? $this->{'local_granule_id'} = shift
                                           : $this->{'local_granule_id'}}
sub status           {my $this = shift; @_ ? $this->{'status'} = shift
                                           : $this->{'status'}}

# Add a file specification to the FILE_GROUP

sub add_file_spec {
    my $this = shift;
    my ($file, $type, $completed)=@_;
    
    # Initialize an array (Why? Seems to be reset later... --Lynnes)
    my @filespeclist=();

    my $r_filespec_list=\@filespeclist;

    $r_filespec_list=$this->file_specs;

    # Create a new S4P::FileSpec object instance
    my $r_filespec = S4P::FileSpec->new();

    # Set the various file attributes of the FileSpec
    $r_filespec->pathname($file);

    # Only add the size if the file exists
    if (-e $file) {
        my $size=-s $file;
        $r_filespec->file_size($size);
    }
    # Is this necessary? Should be set by pathname() above -- Lynnes
    $r_filespec->file_id($file);

    # If the FileSpec is not specified, try to guess it from the extension:
    #  e.g., .pcf -> PCF, .met -> METADATA, .tar -> PRODHIST, 
    #  .jpg or .jpg -> BROWSE, rest is SCIENCE
    $type ? $r_filespec->file_type($type) : $r_filespec->guess_file_type();

    $r_filespec->completed($completed) if $completed;

    push(@{$r_filespec_list},$r_filespec);

    $this->file_specs($r_filespec_list);
}

sub sprint {
    use strict;
    my $this = shift;
    my $spacious = shift;  # Whether or not to use spaces around '='
    my $format = ($spacious) ? "\t%s = %s\;\n" : "\t%s=%s\;\n";
    my $object_tag = ($spacious) ? "OBJECT = FILE_GROUP\;\n" : "OBJECT=FILE_GROUP\;\n";

    my $text = sprintf($object_tag);
    $this->{'data_version'}='000' unless (defined $this->{'data_version'});
    foreach my $attr (@attributes) {
        my $ATTR = uc($attr);
        if (defined $this->{$attr}) {
            $text .= sprintf($format, $ATTR, $this->{$attr});
        }
    }
    if ($this->file_specs) {
        foreach my $file (@{$this->file_specs}) {
            $text .= $file->sprint($spacious);
        }
    }

    $text .= sprintf("END_%s", $object_tag);
    return $text;
}

# return a hash with the keys being all the filenames in the file group
# and the values their directories.
sub load_dirs {
    my $this=shift;

    %fd=();

# NOTE: there is a BUG here. If there are two files with the same name
# in the same file group in different dirs they will overwrite each other.

# loop throught the file_spec and load the hashes
    foreach $file_spec (@{$this->{'file_specs'}}) {
        $fname=$file_spec->file_id();
        S4P::logger("WARNING","Two files with the same name in the same filegroup: $fname") if ($fd{$fname});

        $fd{$fname}=$file_spec->directory_id();
    }
    return %fd;
}

# return a hash with the keys being all the filenames in the file group
# and the values their sizes.
sub load_sizes {
    my $this=shift;

    %fd=();

# NOTE: there is a BUG here. If there are two files with the same name
# in the same file group in different dirs they will overwrite each other.

# loop through the file_spec and load the hashes
    foreach $file_spec (@{$this->{'file_specs'}}) {
        $fname=$file_spec->file_id();
        S4P::logger("WARNING","Two files with the same name in the same filegroup: $fname") if ($fd{$fname});

        $fd{$fname}=$file_spec->file_size();
    }
    return %fd;
}

# return the name of the metfile or else return 0
sub met_file {
    $this=shift;
    local($metfile);

    $metfile=0;

# Search for *.met
    foreach $file_spec (@{$this->{'file_specs'}}) {
        if ( ( (not defined $file_spec->file_type())
               && ($file_spec->{'file_id'} =~ /\.met$/i) )
             || ( $file_spec->file_type() eq 'METADATA' ) ) {
            S4P::logger("WARNING","multiple metfiles in file group") 
                if ($metfile);
            $metfile=$file_spec->{'directory_id'}.'/'.$file_spec->{'file_id'};
        }
    }
    return ($metfile);
}

sub science_files {
    my $this = shift;
    my $file_spec;
    my @files;
    
    foreach $file_spec (@{$this->{'file_specs'}}) {
        if (($file_spec->{'file_type'} eq 'SCIENCE') || ($file_spec->{'file_type'} =~ /^HDF/)) {
            next if ( $file_spec->{'file_type'} eq 'HDF4MAP' );
            push @files, $file_spec->{'directory_id'}.'/'.$file_spec->{'file_id'};
        }
    }
    return @files;
}

# return the name of the browse file or else return 0
sub browse_file {
    $this=shift;
    local($browseFile);

    $browseFile = 0;

# Search for *.jpg or *.jpeg
    foreach $file_spec (@{$this->{'file_specs'}}) {
        if ( ( (not defined $file_spec->file_type())
               && ($file_spec->{'file_id'} =~ /\.(jpg|jpeg)$/i) )
             || ( $file_spec->file_type() eq 'BROWSE' ) ) {
            S4P::logger("WARNING","multiple browse files in file group") 
                if ($browseFile);
            $browseFile = $file_spec->{'directory_id'}.'/'.$file_spec->{'file_id'};
        }
    }
    return ($browseFile);
}

# return the name of the QA file or else return 0
sub qa_file {
    $this=shift;
    local($qaFile);

    $qaFile = 0;

# Search for *.txt
    foreach $file_spec (@{$this->{'file_specs'}}) {
        if ( ( (not defined $file_spec->file_type())
               && ($file_spec->{'file_id'} =~ /\.(txt)$/i) )
             || ( $file_spec->file_type() eq 'QA' ) ) {
            S4P::logger("WARNING","multiple QA files in file group") 
                if ($qaFile);
            $qaFile = $file_spec->{'directory_id'}.'/'.$file_spec->{'file_id'};
        }
    }
    return ($qaFile);
}

# return the name of the HDF4MAP file or else return 0
sub map_file {
    $this=shift;
    local($mapFile);

    $mapFile = 0;

# Search for *.map or *.map.gz
    foreach $file_spec (@{$this->{'file_specs'}}) {
        if ( ( (not defined $file_spec->file_type())
               && ($file_spec->{'file_id'} =~ /\.(map|map\.gz)$/i) )
             || ( $file_spec->file_type() eq 'HDF4MAP' ) ) {
            S4P::logger("WARNING","multiple HDF4MAP files in file group") 
                if ($mapFile);
            $mapFile = $file_spec->{'directory_id'}.'/'.$file_spec->{'file_id'};
        }
    }
    return ($mapFile);
}

# Compute checksum for SCIENCE files
sub checksum {
    my $this = shift;
    foreach $file_spec (@{$this->{'file_specs'}}) {
        if (($file_spec->{'file_type'} eq 'SCIENCE') || ($file_spec->{'file_type'} =~ /^HDF/)) {
            return 0 unless ($file_spec->checksum);
        }
    }
    return 1;
}
# Verify checksum for SCIENCE files
sub verify_checksums {
    my $this = shift;
    my $err = 0;
    foreach $file_spec (@{$this->{'file_specs'}}) {
        if (($file_spec->{'file_type'} eq 'SCIENCE') || ($file_spec->{'file_type'} =~ /^HDF/)) {
            $err++ unless ($file_spec->verify_checksum);
        }
    }
    return (! $err);  # Return 0 if checksum errors encountered
}

# copy file from localhost to local dir
sub file_get {

  my $file_group = shift;       # S4P::FileGroup object to be transferred.
  my $localhost = shift || $file_group->node_name();      # localhost name.
  my $local_dir = shift || '.'; # Local directory.
  my $copy_status = shift || undef;

  foreach my $file_spec ( @{ $file_group->file_specs } ) {

    ( my $source_dir = $file_spec->directory_id ) =~ s#/$##;
    unless ( -d $source_dir ) {
      S4P::logger ( "ERROR", "Local $source_dir does not exists");
    }

    my $data_file = "$source_dir/" . $file_spec->file_id;
    my $local_file = "$local_dir/" . $file_spec->file_id;
    if ( File::Copy::copy( $data_file, $local_file ) ) {
      $copy_status = 1;
      S4P::logger( "INFO", "Success in copy " .  $data_file
                    . " to $local_dir" );
    } else {
      $copy_status = 0;
      S4P::logger ( "ERROR", "Failed to copy " . $data_file
                    . " to $local_dir ($!)" );
    }
  }
  if ($copy_status) {
    return $copy_status;
  } else {
    return undef;
  }

} 
 
sub http_get {
  use strict;
  my $this = shift;       # S4P::FileGroup object to be transferred.
  my $local_dir = shift || '.'; # Local directory.

  # Strip out the netrc "alias" if it exists, and get user/password from .netrc
  my ($node_name, $netrc_entry) = split(':', $this->node_name());
  # S4PM PDR might have NODE_NAME as "hostname:alias" but S4PA PDR only has "hostname".
  # So, we will need to pass the alias if it was defined. 
  # Otherwise, just pass the hostname.
  my ($user, $pwd) = $netrc_entry ? 
    S4P::get_ftp_login($netrc_entry) : S4P::get_ftp_login($node_name);
  my $n;
  foreach my $fs (@ {$this->file_specs} ) {
    # Compose URL to get
    my $fname = $fs->file_id;
    my $dir = $fs->directory_id;
    my $url = sprintf("http://%s/%s/%s", $node_name, $dir, $fname);

    # Make URL request; return as soon as we hit a failure
    my $result = S4P::http_get($url, $user, $pwd);
    return unless $result;
    my $fsize = length($result);
    
    # Write output to disk
    my $local_path = sprintf("%s/%s", $local_dir, $fname);
    unless (open(OUT, ">:raw", $local_path)) {
      S4P::logger("ERROR", "Failed to open file $local_path for writing: $!");
      return;
    }

    # Handle partial writes.
    my $len = $fsize;
    my $offset = 0;
    while ($len) {
      my $written = syswrite(OUT, $result, $len, $offset);
      unless ( defined $written ) {
        S4P::logger("ERROR", "System write error: $!");
        return;
      }
      $len -= $written;
      $offset += $written;
    }
    if ($offset != $fsize) {
      S4P::logger("ERROR", "Wrote only $offset of $fsize bytes to $local_path: $!");
      return;
    }
    unless (close(OUT)) {
      S4P::logger("ERROR", "Failed to close output file $local_path");
      return;
    }
    $n++;
  }
  return $n;
}

# ftp file from remote host to local dir
sub ftp_get {

  my $file_group = shift;       # S4P::FileGroup object to be transferred.
  my $remote_host = shift || $file_group->node_name();      # Remote host name.
  my $local_dir = shift || '.'; # Local directory.
  my $ftp = shift || undef;     # Net::FTP object for persistent connection.
  my $max_attempt = shift || 1; # Max attempts on failure to get a connection.
  my $snooze = shift || 60;     # Snooze time in s for multiple attempts to
                                # get a connection.

  my $time_out = 120;

  # specify default FTP_FIRETYPE_TYPE and 
  my $firewallType = defined $ENV{FTP_FIREWALL_TYPE} ? $ENV{FTP_FIREWALL_TYPE} : 1;
  my $ftpPassive = defined $ENV{FTP_PASSIVE} ? $ENV{FTP_PASSIVE} : 1;

  # Make sure the connection is still alive if an Net::FTP object is passed.
  undef $ftp if ( defined $ftp && !$ftp->_NOOP() );

  # Try to open an FTP connection if one is not already defined.
  unless ( defined $ftp ) {
    while ( $max_attempt-- > 0 ) {
        if ( $ENV{FTP_FIREWALL} ) {
            # Create an Net::FTP object with Firewall option
            my $firewall = $ENV{FTP_FIREWALL};
            $ftp = Net::FTP->new( $remote_host, Timeout => $time_out, 
                Passive => $ftpPassive,
                Firewall => $firewall, FirewallType => $firewallType );
        } else {
            # No firewall specified, let .libnetrc resolve if firewall is required
            $ftp = Net::FTP->new( $remote_host, Timeout => $time_out, 
                Passive => $ftpPassive );
        }
        last if defined $ftp;   # No need to snooze if connection is ready
        S4P::logger( 'WARNING', "FTP connection to $remote_host failed: $!" );
        sleep ( $snooze ) if ( $max_attempt );
    }
    # Give up if FTP connection is not available.
    unless ( $ftp) {
        S4P::logger( 'FATAL',
                     "failed to get an FTP connection to $remote_host" );
        return undef;
    }
    my $status = $ftp->login();

    # Quit on failure to log in.
    unless ( $status ) {
        S4P::logger( 'FATAL',
                     "failed to log into on $remote_host (" . $ftp->message() .  ")" );
        $ftp->quit();
        return  undef;
    }
  }

  foreach my $file_spec ( @{ $file_group->file_specs } ) {
    # Change the mode to binary.
    if ( $file_spec->file_type() eq 'METADATA' ) {
        $ftp->ascii();
    } else {
        $ftp->binary();
    }
    my $ftp_path = $file_spec->directory_id;

    # Save the current directory
    my $cur_dir = $ftp->pwd();

    # Try changing the directory.
    $status = $ftp->cwd( $ftp_path );

    # Quit on failure to change directory.
    unless ( $status ) {
      S4P::logger( 'FATAL',
                   "failed to change directory to $ftp_path on $remote_host("
                   . $ftp->message . ")" );
      $ftp->quit();
      return undef;
    }

    my $data_file_id = $file_spec->file_id;
    my $local_file =  $local_dir .'/'. $data_file_id;

    # download file to local dir
    $status = $ftp->get( $data_file_id, $local_file );

    if ( $status ) {
      S4P::logger( 'INFO',
                   "successfully downloaded $data_file_id to destination"
                   . " $local_dir" );
    } else {
      S4P::logger( 'FATAL',
                   "failed to download $data_file_id to destination $local_dir: "
                   . $ftp->message() );
      $ftp->quit();
      return undef;
    }
    # If working directory was stored, restore it.
    if ( defined $cur_dir ) {
      $status = $ftp->cwd( $cur_dir );
      unless ( $status ) {
	S4P::logger( 'FATAL',
	  "failed to change back to $cur_dir on $remote_host("
	  . $ftp->message . ")" );
	$ftp->quit();
	return undef;
      }
    }
  }

  return $ftp;
}

# sets the protocol to be used for data transfer
sub protocol
{
  my ( $this, $protocol ) = @_;
  if ( defined $protocol ) {
    # if a protocol is not defined, set it. Allow only 'FILE', 'FTP' or 'SFTP'
    if ( $protocol eq 'FTP' || $protocol eq 'SFTP' || $protocol eq 'FILE' || $protocol eq 'BBFTP' || $protocol eq 'HTTP' ) {
      $this->{protocol} = $protocol;
    } else {
      $this->{protocol} = undef;
      S4P::logger( 'FATAL', "Protocol, $protocol, is invalid (valids=FILE, FTP, BBFTP, HTTP or SFTP)" );
    }
  } elsif ( not defined $this->{protocol} ) {
    # by default, set it to 'FTP'
    $this->{protocol} = 'FTP';
  }
  return $this->{protocol};
}

# downloads files via SFTP
sub ssh_get
{
  my ( $this, $remote_host, $local_dir ) = @_;

  my $machine = Net::Netrc->lookup( $remote_host );
  my $login = ( defined $machine ) ? ( $machine->login() ) : undef;
  unless ( defined $login ) {
    S4P::logger( 'ERROR', "Machine/login entry not found in .netrc for $remote_host" );
    return undef;
  }
  my $passwd = ( defined $login ) ? ( $machine->password() ) : undef;
  S4P::logger( "INFO", "Found login info for $remote_host" );

  my $sftp_batch_get = "s4pa_sftp_get_cmd";
  open ( BATCH, "> $sftp_batch_get" );

  my @getFiles;
  # download file
  foreach my $file_spec ( @{ $this->file_specs } ) {
    my $remotePath = $file_spec->pathname();
    my $localPath = "$local_dir/" . $file_spec->file_id;
    print BATCH "get $remotePath $localPath\n";
    push @getFiles, $file_spec->file_id;
  }
  print BATCH "quit\n";
  close ( BATCH );

  # execute sftp through system call for file transfering
  my $status = 0;
  my $sftp_log = "s4pa_sftp.log";
  my $sftp_session = "sftp" . " -b $sftp_batch_get " . "$login\@$remote_host";
  my $sftpStatus = system( "$sftp_session" . "> $sftp_log 2>&1" );
  if ( $sftpStatus ) {
    S4P::logger( "INFO", S4P::read_file( $sftp_log ) ) if ( -f $sftp_log );
    S4P::logger( "ERROR", "Failed on sftp pull from $remote_host" );
  } else {
    foreach my $gotFile ( @getFiles ) {
      S4P::logger( "INFO", "Succeeded on sftp pull $gotFile from $remote_host" );
    }
    $status = 1;
  }
  unlink $sftp_log;
  unlink $sftp_batch_get;
  if ($status) {
      return $status;
  } else {
      return undef;
  }
}

# downloads files via BBFTP
sub bbftp_get
{
  my ( $this, $remote_host, $local_dir, $bbftp, $max_attempt, $snooze ) = @_;

  my $machine = Net::Netrc->lookup( $remote_host );
  my $login = ( defined $machine ) ? ( $machine->login() ) : undef;
  unless ( defined $login ) {
    S4P::logger( 'ERROR', "Machine/login entry not found in .netrc for $remote_host" );
    return undef;
  }
  my $passwd = ( defined $login ) ? ( $machine->password() ) : undef;
  S4P::logger( "INFO", "Found login info for $remote_host" );

  my @getFiles;

  # make file list
  foreach my $file_spec ( @{ $this->file_specs } ) {
    my $remotePath = $file_spec->pathname();
    push @getFiles, $remotePath;
  }

  # execute bbftp through system call for file transfering
  my $status = 0;
  my $connection = S4P::Connection->new( PROTOCOL => 'BBFTP',
                                         HOST => $remote_host,
                                         LOGIN => $login );
  if ( $connection->onError() ) {
      S4P::logger( "ERROR", $connection->errorMessage() );
  }
  my ($bbftpStatus, $bbftp_log) = $connection->mget(@getFiles);

  if ( !$bbftpStatus ) {
      S4P::logger( "INFO", S4P::read_file( $bbftp_log ) ) if ( -f $bbftp_log );
      S4P::logger( "ERROR", "Failed on bbftp pull from $remote_host" );
  } else {
      foreach my $gotFile ( @getFiles ) {
          S4P::logger( "INFO", "Succeeded on bbftp pull $gotFile from $remote_host" );
      }
  }
  # avoid bbFTP problem with timestamp of transfered file.
  foreach my $gotFile (@getFiles) {
      my $localFile = basename $gotFile;
      `touch $localFile`;
      File::Copy::move($localFile, $local_dir);
  }
  $status = 1;
  unlink ($bbftp_log);
  unlink ($bbftp_batch_get);
  if ($status) {
      return $status;
  } else {
      return undef;
  }
}

sub symlinks {
    my ($this, $dir) = @_;

    # First see if we have a place to put them
    unless (-d $dir) {
        S4P::logger("ERROR", "Directory $dir does not exist");
        return;
    }
    # Get pathnames from FILE_GROUP
    my @pathnames = map {$_->pathname} @{ $this->file_specs };

    # FIRST, check existence; don't want to get halfway just to find one missing
    my $err;
    foreach my $path(@pathnames) {
        unless (-f $path) {
            S4P::logger('ERROR', "Cannot find $path");
            $err++;
        }
    }
    return if $err;
    foreach my $path(@pathnames) {
        my $file = "$dir/" . basename($path);
        if (symlink($path, $file)) {
            S4P::logger('INFO', "Created symlink $file -> $path");
        }
        else {
            S4P::logger('ERROR', "Cannot create symlink: $!");
            return;
        }
    }
    my $fg = $this->copy;
    map {$_->directory_id($dir)} @{ $fg->file_specs };
    return $fg;
}
# wrapper to download data
sub download
{
  my ( $this, @argv ) = @_;
  my $protocol = $this->protocol();
  if ( $protocol eq 'FTP' ) {
    return $this->ftp_get( @argv );
  } elsif ( $protocol eq 'SFTP' ) {
    return $this->ssh_get( @argv );
  } elsif ($protocol eq 'BBFTP' ) {
    return $this->bbftp_get( @argv );
  } elsif ( $protocol eq 'FILE' ) {
    return $this->file_get( @argv );
  } elsif ( $protocol eq 'HTTP' ) {
    return $this->http_get( @argv );
  } else {
    S4P::logger( 'ERROR', "Protocol, $protocol, not supported in file group" );
  }
  return undef;
}

# method to get non-metadata files
sub data_files {
    my $this = shift;
    my $file_spec;
    my @files;

    foreach $file_spec (@{$this->{'file_specs'}}) {
        next if ( $file_spec->{file_type} =~ /(METADATA|BROWSE|QA|HDF4MAP)/ );
        push @files, $file_spec->{'directory_id'}.'/'.$file_spec->{'file_id'};
    }
    return @files;
}
