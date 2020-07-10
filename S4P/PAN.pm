=head1 NAME

PAN - Product Acceptance Notification object

=head1 SYNOPSIS

use S4P::PAN;

=over

=item * S4P::PAN->new()

=item * S4P::PAN->new(PDR object)

=item * S4P::PAN->new(text or filename)

=item * $pan->write(filename)

=item * $pan->disposition(filename, disptext, stamptext)

=item * $disptext = $pan->disposition(filename)

=item * $stamptext = $pan->stamp(filename)

=item * $pan->files()

=item * $msg_type = $pan->msg_type()

=back

For backward compatibility:

=over

=item * $test = $pan->is_successful()

=item * $n = $pan->no_of_files()

=item * $goodref = $pan->success_file_list()

=item * $badref = $pan->fail_file_list()

=back

For PDRDs:

=over

=item * S4P::PAN->new(text or filename)

=item * S4P::PAN::read_pan(filename)

=item * $msg_type = $pan->msg_type()

=item * $n = $pan->no_file_grps()

=back

=head1 DESCRIPTION

The PAN module will implement PAN (Product Acceptance Notification)
objects, including construction, reading, writing, and querying. For
backward compatibility with the previous version of the module, reading
and querying capabilities for PDRD (Product Delivery Record
Discrepancy) objects will also be provided. (Details of the PDRD
capability are described in their own section, below.) The capabilities
are based on Revision C of the ECS/SIPS ICD.

In addition, capabilities are provided for writing EDOS-style PAN/EANs.

PANs can be created by fully specifying all fields at once, or they can
be built up piecemeal. At any point, they can be written to a file for
later retrieval and further updating. Values for time stamps and
dispositions are not validated. The object does not enforce the
requirement or proscription of time stamps with certain dispositions as
described in the ICD.

A new S4P::PAN can be constructed from a PAN on file, a string, an empty
list, or a PDR object. An empty list creates a SHORTPAN, with
DISPOSITION="SUCCESSFUL" and an undef TIME_STAMP. A PDR
creates a SHORTPAN with DISPOSITION="SUCCESSFUL" and undef
TIME_STAMPs, but remembers each file of the PDR. If some FILE_GROUPs in
the PDR have non-null, non-"SUCCESSFUL" STATUS fields, these
are applied as dispositions for all files in those groups and the PAN
is promoted to a LONGPAN in the process.

Functions are provided for setting the disposition and/or timestamp for
any given file or for the PAN as a whole. Setting the PAN as a whole is
ignored if the PAN is currently long. Setting for a particular file on
a short PAN converts it (irretrievably) to long, and sets the
DISPOSITION and TIME_STAMP for files other than the specified file to
the previous value of the overall PAN. Setting for a particular file
adds the file if it does not previously exist.

The consequence of these operations is what allows the PAN to be
constructed piecemeal. It can be created initially short and
successful. If it is created from the PDR, only failed dispositions
need to be added, either as a whole or to the failed files.

Filenames passed to and retrieved from PAN methods are single strings.
When written to a file, they are split into FILE_DIRECTORY and
FILE_NAME as specified in the ICD at the last forward slash.

The public methods will be:

=over

=item * $pan = S4P::PAN->new() creates a new SHORTPAN with
DISPOSITION="SUCCESSFUL" and an undef TIME_STAMP

=item * $pan = S4P::PAN->new($PDRobject) creates a SHORTPAN with
DISPOSITION="SUCCESSFUL" and an undef TIME_STAMP, and
remembers the filenames of the PDR; if the PDR contains FILE_GROUPs
that have non-null, non-"SUCCESSFUL" STATUS fields, these are
applied as dispositions for all files in those groups and the PAN is
promoted to a LONGPAN in the process; if $PDRobject->is_edos, information
for buiding a binary EDOS PAN will be extracted (or this can be provided
by edos_header method)

=item * $pan = S4P::PAN->new($text_or_filename) creates a PAN described
by the text or contained in the file; if the file cannot be read, the
error is logged and undef is returned; invalid files can result in
undefined behaviour; support is not provided for reading EDOS-format PANs

=item * $pan->write($filename) writes the PAN to an external file;
undef timestamps are written as 20 blanks.  Note that if the PAN is_edos,
a binary EDOS file is written.

=item * $pan->disposition($filename, $disptext, $stamptext) sets
the disposition and/or timestamp for the corresponding; if filename is
the null string or undef, the PAN as a whole is addressed; if the
filename is unknown to the PAN, it is added (with possible promotion to
a LONGPAN, as described above); disptext is always upshifted and, if
surrounding quotes are not provided they are added; timestamps are
upshifted

=item * $disptext = $pan->disposition($filename) retrieves the
disposition for the filename; if the filename is undef or null, the
disposition of the PAN as a whole is returned---for SHORTPANs this
is the overall disposition, for LONGPANs it is "SUCCESSFUL"
if and only if every file is "SUCCESSFUL" and an arbitrary
disposition otherwise; the returning value is always upper case and
B<always has surrounding quotes, >except that fetching the disposition
of a file from a SHORTPAN or one not in the LONGPAN returns a
completely null string

=item * $stamptext = $pan->stamp($filename) returns the timestamp
for the filename; if the filename is undef or null, the disposition of
the PAN as a whole is returned for SHORTPANs and undef is returned for
LONGPANs; if the timestamp itself is undef, it is returned as a string
of 20 blanks; fetching the timestamp of a file not in the PAN returns a
completely null string

=item * @flist = $pan->files() returns thelist of files (including
path names); the list can be retrieved even from SHORTPANs created from
PDRs

=item * $msg_type = $pan->msg_type() returns SHORTPAN or LONGPAN
depending on the current size of the PAN

=item * $pan->edos_header($PDRobject) extracts from the $pdr information
needed for generating a EDOS PAN if $PDRobject->is_edos is true;  can
also be provided by S4P::PAN->new($PDRobject)

=item * $pan->is_edos returns true if the PAN was created from or
edos_header was set by a PDR/EDR in the EDOS format.

=item * $hdr = $pan->groundmsghdr() returns the 24 byte Ground Message
Header as a 48-character hex string if $pan->is_edos, else undef.  This
returns the groundmsghdr as it was extracted from the PDR/EDR. It is
converted to a PAN GMH only when written.

=back

For backward compatibility:

=over

=item * $pan = S4P::PAN->new('text', $text) returns
S4P::PAN->new($text)

=back

=over

=item * $test = $pan->is_successful() returns
($pan->disposition() eq '"SUCCESSFUL"')

=item * $n = $pan->no_of_files() returns scalar(keys of disposition
hash)) if LONGPAN, else undef

=item * $goodref = $pan->success_file_list() returns a reference to
a list of all files (including path name) in the LONGPAN whose
DISPOSITION is "SUCCESSFUL"; for a SHORTPAN it returns a
reference to a list of all known files if the overall DISPOSITION is
"SUCCESSFUL" and to an empty list if not

=item * $badref = $pan->fail_file_list() returns a reference to a
list of all files (including path name) in the LONGPAN whose
DISPOSITION is not "SUCCESSFUL"; for a SHORTPAN it returns a
reference to an empty list if the overall DISPOSITION is
"SUCCESSFUL" and to a list of all known files if not



=back

=head2 PRDR Processing

For backward compatibility, PAN will also handle PRDRs as follows:

=over

=item * $pdrd = S4P::PAN->new($text_or_filename) creates a PAN object
containing the PRDR described by the text or contained in the file; if
the file cannot be read, the error is logged and undef is returned

=item * $pdrd = S4P::PAN::read_pan($filename) returns
S4P::PAN->new($filename)

=item * $msg_type = $pan->msg_type() returns SHORTPDRD or LONGPDRD
depending on the type of the PDRD stored in the PAN

=item * $n = $pan->no_file_grps() returns NO_FILEGRPS if a LONGPDRD
is stored in the PAN, otherwise undef

=back

No attempt will be made to provide the same behavior where the old
module was undefined (or buggy) or where users were accessing
unadvertised data. (For example, accessing $S4P::PAN::params hash directly
may or may not result in compatible behavior.) No capabilities are
provided for writing PRDRs, setting fields, or fetching dispositions or
file types at this time since the previous module did not provide for
these.


AUTHOR

Dr. C. Wrandle Barth, SSAI, GSFC Code 610.2

=cut

################################################################################
# PAN.pm,v 1.7 2007/02/08 16:24:45 barth Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

#Change history:
# 4/20/01 Chris Added omitted keys( ) in success_ and fail_file_list.
# 4/23/01 Randy Corrected new method invocation within read_pan
# 5/25/01 Randy Allow missing quotes, case blind test on PDR status field.
# 6/20/01 Randy Removed unneeded "use S4P::PDR" from source.
# 11/10/06 Randy Added support for writing EDOS PANs.
# 1/26/07 Randy BZ780 Fix GMH on EDOS PANs to have correct source/destination,
#           and message length fields.
# 2/8/07 Randy BZ834 Add NO_OF_FILES to SIPS PANs.

package S4P::PAN;
use strict;
use S4P;
use S4P::FileGroup;
use S4P::FileSpec;
use Time::Local;


1;

#==============================================================================
# S4P::PAN::new() or S4P::PAN::new(PDR object) or S4P::PAN::new(filename or text)
# returns new S4P::PAN object or undef.

sub new {

#   Get parameter, allocate object hash for SHORTPAN, SUCCESSFUL, unstamped.
    my $class = shift;
    my $parm = shift;
    if ($parm eq "text" and scalar(@_) > 0) {$parm = shift}
    my %obj = ('MESSAGE_TYPE' => 'SHORTPAN',
		'DISPOSITION'  => '"SUCCESSFUL"');
    my $refobj = \%obj;

#   Bless object now so we can use object methods.
    bless $refobj, $class;
#   If parameter is PDR, extract filelist.
    if (ref($parm) eq "S4P::PDR") {
        # Save Ground Message Header and DAN_SEQ_NO from PDR.
        $obj{'groundmsghdr'} = $parm->groundmsghdr;
        $obj{'danseqno'} = $parm->dan_seq_no;
	my @filearr = $parm->files();
	$obj{"files"} = \@filearr;
# 	Extract new STATUS fields for files.
	foreach my $group (@{$parm->file_groups()}) {
	    my $status = $group->status();
	    if (_dispfix($status) ne '"SUCCESSFUL"') { # Save as disposition.
		foreach my $spec (@{$group->file_specs()}) {
		    $refobj->disposition($spec->pathname(), $status);
		}
	    }
	}
    } elsif ($parm ne "") {
	if ($parm !~ /MESSAGE_TYPE\s*=/) {

#	    Open $parm as presumed filename and replace with file contents.
	    $parm = S4P::read_file($parm);

#	    Return on failure (already logged).
            return undef if ($parm eq "0");
        }

#	ICD doesn't allow comments in PANs currently.  If it did, we could
#	extract them here.
	if ($parm !~ /^\s*MESSAGE_TYPE\s*=\s*
			(SHORTPAN|LONGPAN|SHORTPDRD|LONGPDRD)\s*;/mx) {
	    S4P::logger("ERROR", "Invalid MESSAGE_TYPE in PAN.");
	    return undef;
	}
	my $msgtype = $1;
	$obj{"MESSAGE_TYPE"} = $msgtype;
	if ($msgtype eq "SHORTPAN" or $msgtype eq "SHORTPDRD") {
	    # Insure disposotion UC, quoted, nonnull.
	    $obj{"DISPOSITION"} =
		($parm =~ /^\s*DISPOSITION\s*=\s*(.*)\s*;/m) ?
		_dispfix($1) : '"SUCCESSFUL"';
	    $obj{"TIME_STAMP"}  = uc($1)
		if ($parm =~ /^\s*TIME_STAMP\s*=\s*(.*)\s*;/m and $1 ne "");
	} else { # LONGPAN or LONGPDRD
	    $obj{"NO_FILE_GRPS"} = int($1)
		if ($msgtype eq "LONGPDRD" and
		$parm =~ /^\s*NO_FILE_GRPS\s*=\s*(.*)\s*;/m);
	    my $key;			# Will hold key of hash.
	    $obj{"DISPOSITION"} = {};	# Change to hash.
	    $obj{"TIME_STAMP"} = $msgtype eq "LONGPAN" ? {} : undef;
	    while ($parm =~ /^(FILE_DIRECTORY|
				FILE_NAME|
				DISPOSITION|
				TIME_STAMP|
				DATA_TYPE)\s*=\s*(.*)\s*;/mgx) {
		$key = $2 if ($1 eq "FILE_DIRECTORY" or $1 eq "DATA_TYPE");
		$key .= "/$2" if ($1 eq "FILE_NAME");
		$obj{"DISPOSITION"}->{$key} = _dispfix($2) if ($1 eq "DISPOSITION");
		$obj{"TIME_STAMP"}->{$key}  = uc($2) if ($1 eq "TIME_STAMP" and $2 ne "");
	    }
	}
    }
    return $refobj;
}

#==============================================================================
# S4P::PAN::sprint() returns string containing the output PAN (undef for PDRDs).
# A normal PAN is produced even if is_edos is true.  Only PAN::write converts
# to binary.

sub sprint {

    my $this = shift;
    my $msgtype = $this->{"MESSAGE_TYPE"};
    return undef if ($msgtype eq "SHORTPDRD" or $msgtype eq "LONGPDRD");
    my $text = "MESSAGE_TYPE=$msgtype;\n";
    if ($msgtype eq "SHORTPAN") {
	$text .= "DISPOSITION=" . $this->disposition() .
		";\nTIME_STAMP=" . $this->stamp() . ";\n";
    } else { # LONGPAN
        my @filelist = keys %{$this->{"DISPOSITION"}};
        $text .= 'NO_OF_FILES=' . scalar(@filelist) . ";\n";
	foreach my $file (@filelist) {
	    $file =~ m#^((.*)/)?([^/]+)$#;
	    $text .= "FILE_DIRECTORY=$2;\nFILE_NAME=$3;\n";
	    $text .= "DISPOSITION=" . $this->disposition($file) . ";\n";
	    $text .= "TIME_STAMP=" . $this->stamp($file) . ";\n";
	}
    }
    return $text;
}

#==============================================================================
# S4P::PAN::write(filename, [host, remote_dir]) writes PAN to named file,
#       logging failure. The PAN is also sent to a remote host if the optional
#       arguments are given. Does nothing for PDRDs. This does not enforce
#       filename requirements on EDOS PAN/EANs.
sub write {
    my $this = shift;
    my ($filename, $host, $remote_dir) = @_;
    my $msgtype = $this->{"MESSAGE_TYPE"};
    return undef if ($msgtype eq "SHORTPDRD" or $msgtype eq "LONGPDRD");
    my $output;
    if ($this->is_edos) {
        my @filelist = $this->files;
        # Copy original GMH, DAN_SEQ_NO as DDR sequence number.
        $output = pack 'H48xx3x4N',
            ($this->{'groundmsghdr'}, $this->{'danseqno'});
        # Store file count in ASCII.
        $output .= sprintf "%4.4d", scalar(@filelist);
        foreach my $file (sort @filelist) {
      	    my $dispcode = 8; # Unreadable and everything else.
	    my $disp = $msgtype eq 'SHORTPAN' ?
	        $this->{"DISPOSITION"} :
	        $this->{"DISPOSITION"}->{$file};
            $dispcode = 3 if $disp =~ /CHECKSUM/i;
            $dispcode = 9 if $disp =~ /METADATA/i;
            $dispcode = 0 if $disp eq '"SUCCESSFUL"';
            # Extract the directory and file.
	    $file =~ m#^((.*)/)?([^/]+)$#;
	    # ICD says both fields are 256 bytes, but samples show 216 and 40.
	    $output .= pack 'A216A40C', $2, $3, $dispcode;
	}
	# Set total message length in GMH.
	substr($output, 18, 2) = pack('n', length($output));
	# Set PAN length and message type in PAN proper.
	substr($output, 24, 4) = pack('N', length($output) - 24);
	substr($output, 24, 1) = "\x0c";
        # Change PDR's Ground Message Header from x09 or x0b to x0c; fill byte is 01; make
        # source 06 for GSFC and destination 01 for EDOS.
	substr($output, 0, 4) = "\x0c\x01\x06\x01";
	# Overlay PDR's date stamp with current time.
	# They want days since 10/10/1995;
        my $epoch = timegm(0, 0, 0, 10, 9, 1995);
        # Get number of days, discard fraction and modulo to 4 digits.
        my $julday = int((time - $epoch) / (60 * 60 * 24)) % 10000;
        my ($sec, $min, $hour) = gmtime(time);
        $sec += (($hour * 60) + $min) * 60;
        substr($output, 5, 7) = pack("Nxxx", 1 * 2**31 + $julday * 2**17 + $sec);
    } else {
        $output = $this->sprint;
    }
    return 0 unless S4P::write_file($filename, $output);
    return 1 unless $host;

    # specify default firewall type
    my $firewallType = $ENV{FTP_FIREWALL_TYPE} ? $ENV{FTP_FIREWALL_TYPE} : 1;

    my $ftp;
    if ( $ENV{FTP_FIREWALL} ) {
        # Create an Net::FTP object with Firewall option
        my $firewall = $ENV{FTP_FIREWALL};
        $ftp = Net::FTP->new( $host,
            Firewall => $firewall, FirewallType => $firewallType );
    } else {
        # No firewall specified, let .libnetrc resolve if firewall is required
        $ftp = Net::FTP->new( $host );
    }
    unless ($ftp) {
        S4P::logger( 'ERROR', "Failed to get a Net::FTP object ($@)" );
        return 0;
    }
    unless ($ftp->login()) {
        S4P::logger( "ERROR", "Failed to login (" . $ftp->message() . ")" );
        $ftp->close();
        return 0;
    }

    if ($remote_dir) {
        unless ($ftp->cwd($remote_dir)) {
            S4P::logger( "ERROR",
                         "Failed to change directory to $remote_dir ("
                         . $ftp->message() . ")" );
            $ftp->close();
            return 0;
        }
    }

    unless ($ftp->put($filename)) {
        S4P::logger( "ERROR",
                         "Failed to change directory to $remote_dir ("
                         . $ftp->message() . ")" );
        $ftp->close();
        return 0;
    }
    return 1;
}

#==============================================================================
# S4P::PAN::disposition(filename, disptext, stamptext) or S4P::PAN::disposition(filename)
#	First form sets disposition and/or stamp; second fetches disposition.

sub disposition {
    my $this = shift;
    my $msgtype = $this->{"MESSAGE_TYPE"};
    return undef if ($msgtype eq "SHORTPDRD" or $msgtype eq "LONGPDRD");
    my $argcount = @_; 	# Get number of arguments (excluding $this).
    my ($filename, $disptext, $stamptext) = @_;
    # Get current value: string if short, hash ref if long.
    my ($currdisp, $currstamp) = ($this->{"DISPOSITION"}, $this->{"TIME_STAMP"});
    if ($argcount <= 1) { # Fetching disposition.
	if ($filename eq "") { # Overall.
	    if ($msgtype eq "SHORTPAN") {
		return $currdisp;
	    } else { # LONGPAN overall
		foreach my $d (values %{$currdisp}) {
			return $d if ($d ne '"SUCCESSFUL"');
		}
		return '"SUCCESSFUL"';
	    }
	} else { # Fetch for a file.
	    return "" if $msgtype eq "SHORTPAN";
	    my $d = $currdisp->{$filename};
	    return defined($d) ? $d : "";
	}
    } else { # Set value(s).
	if ($filename eq "") { # Overall.
	    if ($msgtype eq "SHORTPAN") { # Set overall for short, ignore long.
		$this->{"DISPOSITION"} = _dispfix($disptext) if ($disptext ne "");
		$this->{"TIME_STAMP"} = uc($stamptext) if ($stamptext ne "");
	    }
	} else { # Set for file.
	    if ($msgtype eq "SHORTPAN") { # Promote SHORTPAN to long.
		$this->{"MESSAGE_TYPE"} = "LONGPAN";
		$this->{"DISPOSITION"} = {};	# Convert strings to hashes.
		$this->{"TIME_STAMP"} = {};
		foreach my $f (@{$this->{"files"}}) {
		    $this->{"DISPOSITION"}->{$f} = $currdisp;
		    $this->{"TIME_STAMP"}->{$f} = $currstamp;
		}
		($currdisp, $currstamp) = ($this->{"DISPOSITION"}, $this->{"TIME_STAMP"});
	    	$this->{"files"} = undef;	# Clear for neatness.
	    }					# Is a LONGPAN now for sure.
	    if ($disptext ne "") {
		$currdisp->{$filename} = _dispfix($disptext);
	    } else { # Don't leave this filename with no disp.
		$currdisp->{$filename} = '"SUCCESSFUL"' if !defined($currdisp->{$filename});
	    }
	    $this->{"TIME_STAMP"}->{$filename} = uc($stamptext) if ($stamptext ne "");
	}
    }
    return "";
}

#==============================================================================
# S4P::PAN::stamp(filename) fetches timestamp for filename or overall if null.

sub stamp {
    my $this = shift;
    my $msgtype = $this->{"MESSAGE_TYPE"};
    return undef if ($msgtype eq "SHORTPDRD" or $msgtype eq "LONGPDRD");
    my $filename = shift;
    my $currstamp = $this->{"TIME_STAMP"};
    if ($filename eq "")  { # Overall.
	return undef if $msgtype eq "LONGPAN";
	return $currstamp eq "" ? " " x 20 : $currstamp;
    } else { # For filename
	return "" if !(exists $currstamp->{$filename});
	$currstamp = $currstamp->{$filename};
	return $currstamp eq "" ? " " x 20 : $currstamp;
    }
}

#==============================================================================
# S4P::PAN::edos_header($pdr) gets Ground Message Header and DAN_SEQ_NO from
# $pdr if $pdr->is_edos.

sub edos_header {
    my ($this, $pdr) = @_;
    if ($pdr->is_edos) {
        $this->{'groundmsghdr'} = $pdr->groundmsghdr;
        $this->{'danseqno'} = $pdr->dan_seq_no;
    }
}

#==============================================================================
# S4P::PAN::groundmsghdr returns the Ground Message Header if is_edos, else undef.

sub groundmsghdr {
    my $this = shift;
    return $this->{'groundmsghdr'};
}

#==============================================================================
# S4P::PAN::is_edos returns true if groundmsghdr is non-null.

sub is_edos {
    my $this = shift;
    return $this->{'groundmsghdr'} ne '';
}


#==============================================================================
# S4P::PAN::files() returns all known files of the PAN.

sub files {
    my $this = shift;
    my $msgtype = $this->{"MESSAGE_TYPE"};
    return undef if ($msgtype eq "SHORTPDRD" or $msgtype eq "LONGPDRD");
    return (@{$this->{"files"}}) if ($msgtype eq "SHORTPAN");
    return keys %{$this->{"DISPOSITION"}}; # For LONGPAN.
}

#==============================================================================
# S4P::PAN::success_file_list() returns a reference to a list of all successful
#	files in the PAN.

sub success_file_list {
    my $this = shift;
    my $msgtype = $this->{"MESSAGE_TYPE"};
    return undef if ($msgtype eq "SHORTPDRD" or $msgtype eq "LONGPDRD");
    my $currdisp = $this->{"DISPOSITION"};
    if ($msgtype eq "SHORTPAN") {
	return $currdisp eq '"SUCCESSFUL"' ? \$this->files() : \();
    }
    my @result = ();
    foreach my $key (keys %{$currdisp}) {
	push @result, $key if ($currdisp->{$key} eq '"SUCCESSFUL"');
    }
    return \@result;
}


#==============================================================================
# S4P::PAN::fail_file_list() returns a reference to a list of all unsuccessful
#	files in the PAN.

sub fail_file_list {
    my $this = shift;
    my $msgtype = $this->{"MESSAGE_TYPE"};
    return undef if ($msgtype eq "SHORTPDRD" or $msgtype eq "LONGPDRD");
    my $currdisp = $this->{"DISPOSITION"};
    if ($msgtype eq "SHORTPAN") {
	return $currdisp ne '"SUCCESSFUL"' ? \$this->files() : \();
    }
    my @result = ();
    foreach my $key (keys %{$currdisp}) {
	push @result, $key if ($currdisp->{$key} ne '"SUCCESSFUL"');
    }
    return \@result;
}

#==============================================================================
# BACKWARD COMPATIBLE ROUTINES
# S4P::PAN::msg_type()

sub msg_type {
    return $_[0]->{"MESSAGE_TYPE"};
}

# S4P::PAN::read_pan(filename)

sub read_pan {
    return S4P::PAN->new($_[0]);
}

# S4P::PAN::no_of_files()

sub no_of_files {
    my $this = shift;
    my $msgtype = $this->{"MESSAGE_TYPE"};
    return scalar(keys %{$this->{"DISPOSITION"}}) if ($msgtype eq "LONGPAN");
    return undef;
}

# S4P::PAN::is_successful()

sub is_successful {
    return $_[0]->disposition() eq '"SUCCESSFUL"';
}

# S4P::PAN::no_file_grps()

sub no_file_grps {
    my $this = shift;
    my $msgtype = $this->{"MESSAGE_TYPE"};
    return $this->{"NO_FILE_GRPS"} if ($msgtype eq "LONGPDRD");
    return undef;
}

#==============================================================================
# Internal routines
#==============================================================================
# S4P::PAN::_dispfix(disptext) returns disptext upshifted and with double quotes
#	surrounding if omitted; if originally null or undef, "SUCCESSFUL" is
#	returned.

sub _dispfix {
	my $disptext = shift;
	return '"SUCCESSFUL"' if ($disptext eq "");
	$disptext =~ s/^([^"])/"$1/;	# Provide omitted leading quotes.
	$disptext =~ s/([^"])$/$1"/;	# Provide omitted trailing quotes.
	$disptext = uc($disptext);
	return $disptext;
}





