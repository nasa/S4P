=head1 NAME

PDR - object implementing a Product Delivery Record

=head1 SYNOPSIS

=for roff
.nf

use S4P::PDR;

$pdr = S4P::PDR::read_pdr($filename);

$pdr = S4P::PDR::create(%filegroupnames);

$pdr = new S4P::PDR('text'=>$text);

$total_file_count = $pdr->total_file_count;

$total_file_size = $pdr->total_file_size;

@file_groups = @{ $pdr->file_groups };

$expiration_time = $pdr->expiration_time;
$pdr->expiration_time(yyyy-mm-ddThh:mm:ssZ);

$originating_system = $pdr->originating_system;
$pdr->originating_system($originating_system);

$processing_start = $pdr->processing_start;
$pdr->processing_start($processing_start);

$processing_end = $pdr->processing_end;
$pdr->processing_end($processing_end);

$processing_offset = $pdr->processing_offset;
$pdr->processing_offset($processing_offset);

$post_processing_offset = $pdr->post_processing_offset;
$pdr->post_processing_offset($post_processing_offset);

$pre_processing_offset = $pdr->pre_processing_offset;
$pdr->pre_processing_offset($pre_processing_offset);

$status = $pdr->status;
$pdr->status($status);

$attempt = $pdr->attempt;
$pdr->attempt($attempt);

$work_order_id = $pdr->work_order_id;
$pdr->work_order_id($work_order_id);

$gmrhex = $pdr->groundmsghdr;
$pdr->groundmsghdr($gmrhex);

$n = $pdr->dan_seq_no;
$pdr->dan_seq_no($n);

$pdr->is_edos;

@files = $pdr->files( [$type_name] );

@files = $pdr->files_by_type($type_name);

@file_specs = $pdr->file_specs();

$pdr->write_pdr($filename);

$n_errors = $pdr->errors();

$count = $pdr->recount();

$rc = $pdr->resolve_paths();

$new_pdr = $pdr->copy;

%pdrs = $pdr->split( $attribute );

@pdrs = $pdr->split( $split_function );

$pdr->sort_by_dir();

$ngran = $pdr->ftp_get($local_dir, $max_attempts, $snooze)

$ngran = $pdr->http_get($local_dir)

=head2 S4P-specific Additions

$pdr = S4P::PDR::start_pdr('processing_start'=>$start, 'processing_stop'=$stop,
    'post_processing_offset'=>$offset_sec,
    'pre_processing_offset'=>$offset_sec,
    'work_order_id'=>$filename);

$file_group = $pdr->add_granule('ur'=$ur,
                                'data_type'=>$esdt,
                                'data_version'=>$version,
                                'lun'=>$lun,
                                'need'=>$need,
                                'timer'=>$timer,
                                'node_name'=>$hostname,
                                'files'=>\@files);

$pdr->pop_granule();

$str = show_file_groups(@file_groups);

$str = show_file_specs(@file_specs);

$hostname = S4P::PDR::gethost();

$pdr->checksum();

$pdr->verify_checksums();

=head1 DESCRIPTION

The PDR object implements a Product Delivery Record, more or less as described
in the various ECS ICDs.

=over 4

=item read_pdr

Reads in a PDR, instantiates a new object and returns it.
If the file cannot be read, the error is logged and undef is returned.
An error string is cached in $S4P::PDR::errstr, and error code in $S4P::PDR::err.
 1 = Failed to read PDR file
 2 = Failed parsing FILE_GROUP
 3 = File count mismatch
Note that if the file contains an EDOS-style PDR/EDR, the binary Ground Message Header is
stripped from the front and stored as though it were a hex string in groundmsghdr.

=item create

Makes a new SIPS-style PDR for groups of files.
Input is a hash where the key is a group name and
value is a reference to a list of files with paths.

S4P::PDR->new is another way of instantiating a PDR; the text to be parsed
can be passed in as the argument, as 'text'=>$text.  This returns undef
if the text is passed in, but blank.

The PDR has attributes which can be retrieved or set: expiration_time
(in the format YYYY-MM-DDTHH:MM:SSZ) and originating_system,
The total_file_count attribute can be retrieved; it is computed
automatically when the PDR is parsed.

=item files

The method B<files> returns a list of all the files in the PDR.

=item files_by_type

The method B<files_by_type> returns a list of files matching a certain
type, such as "PCF".  The list contains full pathnames.
This is deprecated, as calling the B<files> method with the optional
I<type_name> argument achieves the same result.

=item file_specs

The method B<file_specs> returns the list of FileSpec objects in the PDR.

=item write_pdr

The B<write_pdr> method writes a PDR to the filename specified in the argument.
This has an odd return code:  0 on success, non-zero otherwise, for historical
reasons.  Note that even if is_edos is true, a SIPS-style PDR is written and the
Ground Messaeg Header will appear as a hex character string.

=item total_file_size

The B<total_file_size> method returns the sum of all the file sizes listed in
the PDR.

=item start_pdr

B<start_pdr> is used to start a PDR.  It can take ECS (originating_system,
expiration_time) or S4P-specific PDR-level attributes (processing_start,
processing_stop).

=item add_granule

B<add_granule> is a companion to B<start_pdr>; it adds a I<file_group> to the
PDR.  It can also take ECS or S4P-specific file_group-level attributes.
N.B.:  it takes a I<reference> to a list of file pathnames, i.e., not the
list itself, nor a reference to file_spec objects.

=item pop_granule

Deletes the last I<file_group>, and returns the I<file_group>
object, similar to the more generic pop command.

=item gethost

A convenience routine to get the current hostname so that it
can be added as a node_name attribute in add_granule.

=item ftp_get

This method iterates over the FileGroups in the PDR, calling the
respective ftp_get method in that object.
It tries to keep a persistent connection, but then logs out at the end.

=item http_get

Iterate over the FILE_GROUPS in the PDR, calling the
FileGroup::http_get method for each FILE_GROUP.

Returns the number of files transferred, if successful.
If a transfer error is encountered, it quits and returns undef.

=item errors

Checks the paths in the PDR for non-existent files, logging the
errors and returning the number of errors.  Thus a return of 0 is a success.

=item recount

Resets the TOTAL_FILE_COUNT attribute of the PDR to the total number of
FILE_SPEC objects currently in the PDR.  If you are adding or subtracting
FILE_SPECs or FILE_GROUPs to a PDR, this should be called before writing it out.

=item resolve_paths

B<resolve_paths> resolves the full paths of directory_ids in the file_specs
which include '..' in them.  It then changes the directory_id in the
file_spec to the resolved path.  This is recommended for most, if not all
PDRs.

=item show_file_groups

B<show_file_groups> simply takes as an argument an array of PDR file
groups and returns a "pretty" formatted string containing the file groups
in that array. It uses B<show_file_specs> to format the internal file
specs in each file group. It is most useful for debugging purposes.

=item show_file_specs

B<show_file_specs> simply takes as an argument an array of PDR file
group file specs and returns a "pretty" formatted string containing
those file specs. It is primarily used by B<show_file_groups> to format
the internal file specs found in a file group. It is most useful for
debugging purposes.

=back

=head2 S4P-specific extensions to the ECS PDR format

=over 4

=item attempt

Can be used to store/retrieve the number of times a PDR is processed.

=item status

Displays the PDR status. Status can be set explicitly. If not set, it
is deduced based on the status of FileGroups. For deducing status,
FileGroups must use SUCCESSFUL or FAILURE as their status.

=item processing_start

Processing start time in CCSDSa format (YYYY-MM-DDTHH:MM:SS.SSZ).

=item processing_stop

Processing start time in CCSDSa format (YYYY-MM-DDTHH:MM:SS.SSZ).

=item post_processing_offset, processing_offset

post_processing_offset and processing_offset are equivalent for backward
compatibility. post_processing_offset, however, should be used in preference
to processing_offset as the former will be deprecated someday.

By default, the beginning of the PGE processing period is aligned with the
start time of the input trigger data. An offset from that alignment
can be specified here as positive or negative seconds. If postive, the
processing period will start AFTER the trigger data time by the amount
specified. If negative, the processing period will start BEFORE the trigger
data time by the same amount. The default is zero if not specified.

The offset is applied in a post examination sense. That is, the determination
of data times is done relative to the processing period assuming NO offset
(e.g. the definition of current or previous granule is is based on NO offset).
Only at the point where the processing start and stop are written into the
output PDR is the processing offset applied.

See pre_processing_offset to apply the offset before data times relative to
the processing period are calculated.

=item pre_processing_offset

By default, the beginning of the PGE processing period is aligned with the
start time of the input trigger data. An offset from that alignment
can be specified here as positive or negative seconds. If postive, the
processing period will start AFTER the trigger data time by the amount
specified. If negative, the processing period will start BEFORE the trigger
data time by the same amount. The default is zero if not specified.

The offset is applied in a pre examination sense. That is, the determination
of data times is done relative to the processing period assuming this offset
(e.g. the definition of current or previous granule is is based on this
offset).

See post_processing_offset to apply the offset AFTER data times relative to
the processing period are calculated.

=item checksum

Compute checksums for all SCIENCE-type FILE_SPECs in a PDR.

=item verify_checksums

Verify checksums for all SCIENCE-type FILE_SPECs in a PDR.

=item copy

Makes a copy of the PDR, and all its FILE_GROUPS too.

=item split

Split PDR into multiple PDRs based either on a FILE_GROUP attribute
(like 'data_type') or a caller-supplied subroutine.  For example:

    %pdrs = $pdr->split('data_type');

creates one PDR for each distinct DATA_TYPE in the original PDR.
The keys will be the data_type values.

An example of a function would be:

    %pdrs = $pdr->split(sub {return ($_->data_type =~ /^MOD35/)});

This splits into two PDRs, one with data types starting with MOD35,
one without.  The keys are 1 and, um, not-one (undef? 0? ''?).

Note that the FILE_GROUP objects are not copied, just referenced.
Changing them in the child PDRs changes them in the parent as well.

=item sort_by_dir

Sorts by the directory of the first file in each FILE_GROUP.
This can be used as a proxy for time-sorting multi-file granules within a PDR.

=item is_edos

Tests whether groundmsghdr is null.

=item is_expedited

Tests whether the groundmsghdr begins with '0B' (expidited data, EDR).  Always
false if !is_edos.

=back

=head1 EXAMPLES

=head2 Reading / parsing a PDR file

 use S4P::PDR;
 $pdr = new S4P::PDR('text' => S4P::read_file($filename));

=head2 Constructing a PDR from Scratch

 use S4P::PDR;
 my $pdr = S4P::PDR::start_pdr('processing_start'=>'2000-03-23T02:05:00Z',
                         'processing_stop'=>'2000-03-23T02:10:00Z');
 my $host = S4P::PDR::gethost;
 $pdr->add_granule(
  'ur'=>'UR:10:DsShESDTUR:UR:15:DsShSciServerUR:13:[GSF:DSSDSRV]:18:SC:MOD000.001:6875',
  'data_type'=>'MOD000', 'data_version' => '001', 'node_name'=>$host,
  'data_start' => '2000-03-23T02:00:00Z', 'data_end' => '2000-03-23T04:00:00Z',
  'need' => OPT2, 'timer' => 1800, 'lun' => 500100,
  'files' => ['/usr/data/P0420064AAAAAAAAAAAAAA00200160307001.PDS',
              '/usr/data/P0420064AAAAAAAAAAAAAA00200160307000.PDS'],
 );

=head1 SEE ALSO

L<FileGroup (3)>, L<FileSpec (3)>.

=head1 DIAGNOSTICS

If parsing fails, it will report which FILE_GROUP it failed on 
(starting with 1).

=head1 AUTHORS

Chris Lynnes, NASA/GSFC, Code 610.2

Daniel Ziskin, George Mason University

Randy Barth, ADNET

11/10/06 Added EDOS handling
02/02/07 Added EDOS expidited handling (EDR).

=cut

################################################################################
# PDR.pm,v 1.23 2017/03/17 20:26:31 mtheobal Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P::PDR;
use Cwd;
use S4P::FileGroup;
use S4P::FileSpec;
use S4P;
my @ecs_attributes = ('originating_system', 'total_file_count',
                      'expiration_time', 'groundmsghdr', 'dan_seq_no');
my @s4p_attributes = ('processing_start', 'processing_stop',
                      'processing_offset', 'work_order_id',
                      'post_processing_offset', 'pre_processing_offset');
my @s4pa_attributes = ('subscription_id', 'status', 'attempt');
my @attributes;
push @attributes, @ecs_attributes, @s4p_attributes, @s4pa_attributes;
$S4P::PDR::errstr = '';
$S4P::PDR::err = 0;
1;

# read_pdr: read a pdr file and load it into a pdr structure
sub read_pdr {
    my $file = shift;
    my $text = S4P::read_file($file);
    if (! $text) {
        $S4P::PDR::errstr = "Failed to read PDR file $file: $!";
        $S4P::PDR::err = 1;
        return;
    }
    # Strip off binary GMH and save as hex field.  Drop Exchange
    # Data Unit Label and Delivery Record Label, 20 bytes each.
    my $first2bytes = substr($text, 0, 2);
    if ($first2bytes eq "\x09\x00" or $first2bytes eq "\x0b\x00") {
        $text = 'GROUNDMSGHDR = ' .
            unpack('H48', substr($text, 0, 24)) . ";\n" .
            substr($text, 24 + 20 + 20);
        # Remove ^M in new lines (Windows-style);
        $text =~ s/\x0c\x0a/\x0a/gs;
    }
    return ( S4P::PDR->new( 'text' => $text ) );
}

sub show_file_specs {

################################################################################
#                               show_file_specs                                #
################################################################################
# PURPOSE: Show the contents of one or more file specs                         #
################################################################################
# DESCRIPTION: show_file_specs returns a formatted string containing the       #
#              contents of one or more file specs. It is intended for debugging#
#              purposes only.                                                  #
################################################################################
# RETURN: $filespec_str - formatted string containing the contents of file     #
#                         specs                                                #
################################################################################
# CALLS: S4P::logger                                                           #
################################################################################

    my (@file_specs) = @_;

    my $filespec_str;

    foreach my $file_spec (@file_specs) {
        my $str = "\n\tFile Spec:\n\n"
            . "\t\t" . "Directory: " . $file_spec->directory_id . "\n"
            . "\t\t" . "File Name: " . $file_spec->file_id . "\n"
            . "\t\t" . "File Type: " . $file_spec->file_type . "\n"
            . "\t\t" . "File Size: " . $file_spec->file_size . "\n";
        $filespec_str .= $str;
    }

    return $filespec_str;
}

sub show_file_groups {

################################################################################
#                               show_file_groups                               #
################################################################################
# PURPOSE: Show the contents of one or more file groups                        #
################################################################################
# DESCRIPTION: show_file_groups returns a formatted string containing the      #
#              contents of one or more file groups. It is intended for         #
#              debugging purposes only.                                        #
################################################################################
# RETURN: $filegroup_str - formatted string containing the contents of file    #
#                          groups                                              #
################################################################################
# CALLS: S4P::logger                                                           #
#        show_file_specs                                                       #
################################################################################

    my (@file_groups) = @_;

    my $filegroup_str;
    my $filespec_str;

    foreach my $file_group (@file_groups) {
        my $str = "\nFile Group:\n\n"
            . "\t" . "Data Type: " . $file_group->data_type . "\n"
            . "\t" . "Data Version: " . $file_group->data_version . "\n"
            . "\t" . "Data Start: " . $file_group->data_start . "\n"
            . "\t" . "Data End: " . $file_group->data_end . "\n"
            . "\t" . "Need: " . $file_group->need . "\n"
            . "\t" . "Currency: " . $file_group->currency . "\n"
            . "\t" . "Timer: " . $file_group->timer . "\n"
            . "\t" . "UR: " . $file_group->ur . "\n"
            . "\t" . "LUN: " . $file_group->lun . "\n";

        my @file_specs = @{$file_group->file_specs};
        my $str2 = show_file_specs( @file_specs );
        $str .= $str2;
        $filegroup_str .= $str;
    }

    return $filegroup_str;

}

# sprint: returns a string containing the new output PDR
sub sprint {
    my $this = shift;
    my $spacious = shift;  # whether to use spaces surrounding '='
    my $pdr;
    my $format = ($spacious) ? "%s = %s\;\n" : "%s=%s\;\n";

    if ($this->total_file_count == 0 && $this->file_groups) {
        $this->total_file_count($this->compute_total_file_count);
    }
    foreach $k (@attributes) {
	$K = uc($k);
        if (defined $this->{$k}) {
	    $pdr .= sprintf($format, $K, $this->{$k});
        }
    }

    foreach $filegroup (@{$this->file_groups}) {
	$pdr .= $filegroup->sprint($spacious);
    }
    return $pdr;
}

# write_pdr: convenience routine to write a pdr to a file
sub write_pdr {
    my $this = shift;
    my($filename, $spacious) = @_;
    if (! $filename) {
        S4P::logger "ERROR", "No filename specified in write_pdr()";
        return 5;
    }
    # N.B.: The return code of write_pdr is the reverse of the normal
    # convention for historical reasons--C. S. Lynnes
    return (S4P::write_file($filename, $this->sprint($spacious)) ? 0 : 1);
}

# create:  create a PDR with input of a hash where the key is a group name and
# value is a reference to a list of files
sub create {
    my $pdr;

    $pdr = new S4P::PDR;
    $pdr->originating_system('S4P00');
    $exp_time=&get_exp_time(2,'weeks');
    $pdr->expiration_time($exp_time);

    %input=@_;
    @groups=keys(%input);
    $host=$ENV{'HOST'};

    foreach $group (@groups) {
		next if ($group =~ /version/i);
		$input{'version'}=0 unless ($input{'version'});
		$pdr->add_file_group($group,$input{'version'},@{$input{$group}});
    }

    $pdr->total_file_count($pdr->compute_total_file_count);

    return $pdr;
}

sub start_pdr {
    my %attrs = @_;
    my $pdr = new S4P::PDR(%attrs);
    foreach $attr(keys %attrs) {
        $pdr->$attr($attrs{$attr});
    }
    return $pdr;
}
sub add_granule {
    my $this = shift;
    my %attributes = @_;       # Parameters passed in as a hash.
    my $parameter;
    my $file_group = new S4P::FileGroup;
    # Go through arglist parameters; 'files' is treated specially
    foreach $parameter(keys %attributes) {
        # files is the list of full pathnames for the FILE_SPECs
        if ($parameter eq 'files') {
            my @files = @{ $attributes{$parameter} };
            foreach $file (@files) {
                $type = S4P::FileSpec::guess_file_type($file);
	        $file_group->add_file_spec($file,$type);
            }
        }
        # Just regular FILE_GROUP attributes
        else {
            $file_group->$parameter($attributes{$parameter});
        }
    }
    # Add node_name if not specified
    $file_group->node_name(gethost()) unless $file_group->node_name;
    my $r_filegroup_list=$this->file_groups;
    push(@{$r_filegroup_list},$file_group);
    $this->file_groups($r_filegroup_list);
    $this->total_file_count($this->compute_total_file_count);
    return $file_group;
}
sub pop_granule {
    my $this = shift;
    my $r_filegroup_list = $this->file_groups;
    my $file_group = pop(@$r_filegroup_list);
    $this->total_file_count($this->compute_total_file_count);
    return ($file_group);
}

# add_file_group:  add a FileGroup structure to the PDR
sub add_file_group {
    my $this = shift;
    my ($group,$version,@files)=@_;
    my $filegroup;

    # Pre-fab filegroup is passed on, or...
    if (ref $group) {
        $filegroup = $group;
    }
    # Construct one on the fly from a list of files
    else {
        $filegroup = S4P::FileGroup->new();
        $filegroup->data_type($group);
        $filegroup->data_version($version);
        $filegroup->node_name($host);
        foreach $file (@files) {
            $type = S4P::FileSpec::guess_file_type($file);
	    $filegroup->add_file_spec($file,$type);
        }
    }
    my $r_filegroup_list=$this->file_groups;
    push(@{$r_filegroup_list},$filegroup);
    $this->file_groups($r_filegroup_list);
}

# get_exp_time:  get expiration time from PDR
sub get_exp_time {
    local($howmuch,$units)=@_;

    %unitlist=(
	       seconds => 1,
	       minutes => 60,
	       hours => 3600,
	       days => 86400,
	       weeks => 604800,
	       months => 2592000,
	       years => 31557600
	       );

    $offset=$howmuch * $unitlist{$units};

    die "expiration date error\n" if ($offset <= 0 );

    # local time in seconds since 1970

    $time=time();

    #add two weeks

    $time += $offset;

    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($time);

    $mon++;

    # Y2K compliant
    $yyyy=1900 + $year;
    $mm=&mk_2digit($mon);
    $dd=&mk_2digit($mday);
    $hh=&mk_2digit($hour);
    $mi=&mk_2digit($min);
    $ss=&mk_2digit($sec);

    $e_time=join('-',($yyyy,$mm,$dd));

    $e_time .='T'.$hh.':'.$mi.':'.$ss.'Z';

    return($e_time);
}

sub mk_2digit {
    local($invar)=@_;

    if ($invar < 10) {
        $outvar='0'.$invar;
    }
    else {
        $outvar=$invar;
    }
    return ($outvar);
}

sub new {
    my $pkg = shift;
    my %params = @_;
    my $file_group;

    # If text is set, parse it for a FILE_GROUP structure
    if (exists $params{'text'}) {

        my $text = $params{'text'};
        if (! $text) {
            S4P::logger("ERROR","Blank text passed in at PDR creation");
            return undef;
        }
        # Strip comments and blank lines
        $text =~ s/\n\s*#.*?\n/\n/g;  # Comment lines
        $text =~ s/\n\s*\n/\n/g;      # Blank lines
        $text =~ s/^\s*#.*?\n//g;     # Initial comment line
        $text =~ s/^\s*\n//g;         # Initial blank line

        # Get PDR-level attributes
        foreach $attr(@attributes) {
            if ($text =~ /$attr\s*=\s*(.*?);/i) {
                $params{$attr} = $1;
            }
        }
        my @file_groups;
        # Loop through parsing FileGroups by instantiating new S4P::FileGroup objects
        my $nfg = 0;
        while ($text =~ m/(OBJECT\s*=\s*FILE_GROUP;.*?OBJECT\s*=\s*FILE_GROUP;)/gs)
        {
            $file_group = S4P::FileGroup->new('text'=>$1);
            $nfg++;
            if (! $file_group || ! scalar(@{$file_group->file_specs})) {
                $S4P::PDR::errstr = "Error parsing PDR FILE_GROUP number $nfg";
                $S4P::PDR::err = 2;
                S4P::logger("ERROR", $S4P::PDR::errstr);
                return undef;
            }
            push @file_groups, $file_group;
        }
        $params{'file_groups'} = \@file_groups;
    }
    my $r_pdr = \%params;
    bless $r_pdr, $pkg;

    # Count the files and check against "invoice"
    if ($params{'file_groups'}) {
        # If not supplied, this call will compute_total_file_count
        # (which will of course guarantee a match).
        my $invoice = $r_pdr->total_file_count;
        my $actual = $r_pdr->compute_total_file_count;
        if (defined $invoice) {
            if ($invoice != $actual) {
                $S4P::PDR::errstr = "Error in PDR: file count mismatch TOTAL_FILE_COUNT=$invoice, ACTUAL=$actual";
                $S4P::PDR::err = 3;
                S4P::logger("ERROR", $S4P::PDR::errstr);
                return undef;
            }
        }
    }
    $S4P::PDR::err = 0;
    $S4P::PDR::errstr = '';
    return $r_pdr;
}

#  Attribute get/set routines
sub originating_system {my $this=shift; @_ ? $this->{'originating_system'}=shift
                                           : $this->{'originating_system'}}
sub expiration_time  {my $this = shift; @_ ? $this->{'expiration_time'} = shift
                                           : $this->{'expiration_time'}}
sub file_groups      {my $this = shift; @_ ? $this->{'file_groups'} = shift
                                           : $this->{'file_groups'}}
sub groundmsghdr     {my $this = shift; @_ ? $this->{'groundmsghdr'} = shift
                                           : $this->{'groundmsghdr'}}
sub dan_seq_no       {my $this = shift; @_ ? $this->{'dan_seq_no'} = shift
                                           : $this->{'dan_seq_no'}}

sub attempt {my $this = shift; @_ ? $this->{'attempt'} = shift
                                  : $this->{'attempt'}}
sub status {
    my ($this, $status) = @_;
    if ( defined $status ) {
        $this->{'status'} = $status;
    } else {
	my $status;
        foreach my $fg ( @{$this->file_groups} ) {
	    $status = "FAILURE" if ( $fg->status() eq "FAILURE" );
	    last if defined $status;
	}
	$status = "SUCCESSFUL" unless defined $status;
	$this->{'status'} = $status;
    }
    return $this->{'status'};
}

# Non-ECS-standard attributes
sub processing_start {my $this=shift; @_ ? $this->{'processing_start'}=shift
                                         : $this->{'processing_start'}}
sub processing_stop  {my $this=shift; @_ ? $this->{'processing_stop'}=shift
                                         : $this->{'processing_stop'}}
# Note:  May need to set offset to 0
sub processing_offset  {my $this=shift; defined($_[0])
                                         ? $this->{'processing_offset'}=shift
                                         : $this->{'processing_offset'}}
sub post_processing_offset  {my $this=shift; defined($_[0])
                                      ? $this->{'post_processing_offset'}=shift
                                      : $this->{'post_processing_offset'}}
sub pre_processing_offset  {my $this=shift; defined($_[0])
                                      ? $this->{'pre_processing_offset'}=shift
                                      : $this->{'pre_processing_offset'}}
sub work_order_id  {my $this=shift; @_ ? $this->{'work_order_id'}=shift
                                         : $this->{'work_order_id'}}

sub is_edos {my $this=shift; return ($this->groundmsghdr ne '');}

sub is_expedited {my $this=shift; return ($this->groundmsghdr =~ /^0b/i);}

sub total_file_count {
    my ($this, $count) = @_;
    if (defined $count) {
        $this->{'total_file_count'} = $count;
    }
    elsif (! defined $this->{'total_file_count'}) {
        $this->{'total_file_count'} = $this->compute_total_file_count;
    }
    return $this->{'total_file_count'};
}

sub errors {
    my $this = shift;
    my @file_specs = $this->file_specs;
    my $pathname;
    my $errors = 0;
    if (! @file_specs) {
        S4P::logger('ERROR', 'No file specs in PDR');
        return 1;
    }
    foreach $file_spec(@file_specs) {
        $pathname = $file_spec->pathname;
        if (! -e $pathname) {
            S4P::logger('ERROR', "PDR file $pathname does not exist");
            $errors++;
        }
    }
    return $errors;
}
sub compute_total_file_count {
    my $this = shift;
    my $total = 0;
    if ($this->file_groups) {
        foreach $file_group(@{$this->file_groups}) {
            $total += scalar @{$file_group->file_specs};
        }
    }
    return $total;
}

sub total_file_size {
    my $this = shift;
    my $total_file_size=0;

    foreach $file_group(@{$this->file_groups}) {
        foreach $file_spec (@{$file_group->{'file_specs'}}) {
            $total_file_size += $file_spec->file_size();
        }
    }
    return ($total_file_size);
}

# files_by_type:  Return a list of files matching a certain file_type.
#                 This routine is no longer necessary, as calling the files
#                 method with the same arguement achieves the same result,
#                 but is currently retained for historical purposes.
sub files_by_type {
    my ($this, $file_type) = shift;
    return $this->files($file_type);
}
# files:  Return a list of the files in the PDR.  If there is an optional
#         file_type argument, only files of that type are returned.
sub files {
    my $this = shift;
    my $file_type = shift;
    my @files;
    foreach $file_group(@{$this->file_groups}) {
        foreach $file_spec(@{$file_group->file_specs}) {
            if (! $file_type || $file_spec->file_type eq $file_type) {
               push @files, $file_spec->pathname;
            }
        }
    }
    return @files;
}
# file_specs:  Return a list of the FileSpec objects in the PDR.
sub file_specs {
    my $this = shift;
    my @file_specs;
    foreach $file_group(@{$this->file_groups}) {
        push @file_specs, @{$file_group->file_specs};
    }
    return @file_specs;
}

sub http_get {
    use strict;
    my ($this, $local_dir) = @_;
    my $nfiles;
    foreach my $fg (@ {$this->file_groups}) {
        my $n = $fg->http_get($local_dir);
        if ($n) {
            $nfiles += $n;
        }
        else {
            S4P::logger('ERROR', "Encountered error in PDR transfers, stopping...");
            return;
        }
    }
    return $nfiles;
}
# Loop through file_groups, calling the ftp_get method.
# $ftp = $fg->ftp_get($remote_host, $local_dir, $ftp, $max_attempts, $snooze);
sub ftp_get {
    my ($this, $local_dir, $max_attempts, $snooze) = @_;
    require Net::FTP;
    $max_attempts ||= 1;
    $snooze ||= 600;
    my $last_node;
    my ($ftp, $err);
    my $n;
    foreach my $fg(@{$this->file_groups}) {
        my $node = $fg->node_name;
        if ($node ne $last_node) {
            $ftp->quit() if $ftp;
            undef($ftp);
            $last_node = $node;
        }
        $ftp = $fg->ftp_get($node, $local_dir, $ftp, $max_attempts, $snooze);
        $err++ if (! defined $ftp);
        $n++;
    }
    $ftp->quit() if $ftp;
    return ( (! $err), $n);
}

# Loop through file_groups, calling the ssh_get method.
# $ftp = $fg->ssh_get($remote_host, $local_dir, $ssh, $max_attempts, $snooze);
sub ssh_get {
    my ($this, $local_dir) = @_;
    my $last_node;
    my ($ssh, $err);
    my $n;
    my $stat = undef ;
    foreach my $fg(@{$this->file_groups}) {
        my $node = $fg->node_name;
        if ($node ne $last_node) {
            $last_node = $node;
        }
        my $remote_host = $fg->node_name();
        $stat = $fg->ssh_get($remote_host, $local_dir);
        $err++ unless ($stat);
        $n++;
    }
    return ( (! $err), $n);
}

sub gethost {
    my $host = `hostname`;
    chomp($host);
    my ($name, $aliases) = gethostbyname($host);
    return $name;
}

sub recount {
    my $this = shift;
    $this->total_file_count($this->compute_total_file_count);
}

sub resolve_paths {
    my $this = shift;
    my ($file_spec, $dir);
    my $errors = 0;

    # Save the current working directory
    my $here = cwd();

    # Loop through each file_spec in the PDR...
    foreach $file_spec($this->file_specs) {
        $dir = $file_spec->directory_id;
        # If a relative path is included:
        #   chdir to the directory
        #   get cwd()
        #   chdir back to here
        if ($dir =~ m#(^|/)\.\.(/|$)#) {
            if (chdir($dir)) {
                $file_spec->directory_id(cwd());
                chdir($here);
            }
            else {
                $errors++;
                S4P::logger('ERROR', "Could not chdir to $dir: $!");
            }
        }
    }
    # 0 if errors are found, non-zero otherwise
    return (! $errors);
}

# Compute checksums or all SCIENCE-type files
sub checksum {
    my $this = shift;
    foreach my $fg(@{$this->file_groups}) {
        return 0 unless ($fg->checksum);
    }
    return 1;
}
# Verify checksums or all SCIENCE-type files
sub verify_checksums {
    my $this = shift;
    my $err = 0;
    foreach my $fg(@{$this->file_groups}) {
        $err++ unless ($fg->verify_checksums);
    }
    return (! $err);  # Return 0 if errors
}

# Make a copy of a PDR

sub copy {
    my $this = shift;

    # Copy individual FILE_GROUPS
    my @file_groups = map {$_->copy} @{$this->file_groups};
    my %params = ('file_groups' => \@file_groups);

    # Copy all attributes that are set
    foreach my $attr (@attributes) {
        $params{$attr} = $this->{$attr} if (exists($this->{$attr}));
    }
    my $pdr = new S4P::PDR(%params);
    return $pdr;
}

# Split PDR into multiple PDRs
sub split {
    my $pdr = shift;
    my $unique = shift;
    my %file_groups;
    # Default uniquifier function is based on FILE_GROUP attribute value
    my $uniq_sub = (ref($unique) eq "CODE") ? $unique :
        sub {return $_[0]->{$unique}};

    # Loop through file_groups and put them in a hash keyed
    # on the unique value returned by the uniquifying (sorting) function
    foreach my $fg(@{$pdr->file_groups}) {
        my $val = &$uniq_sub($fg);
        push @{$file_groups{$val}}, $fg;
    }

    # Foreach unique set of file_groups, "clone" a PDR
    my %pdrs;
    foreach (keys %file_groups) {
        my %params = ('file_groups' => $file_groups{$_});
        foreach my $attr (qw(originating_system expiration_time
                            work_order_id processing_start processing_stop
                            processing_offset post_processing_offset
                            pre_processing_offset)) {
            $params{$attr} = $pdr->{$attr} if (exists($pdr->{$attr}));
        }
        $pdrs{$_} = S4P::PDR->new(%params);
    }
    return %pdrs;
}
# Sort by directory
sub sort_by_dir {
    my $pdr = shift;
    # Sort by directory of first FILE_SPEC in each FILE_GROUP
    my @sort_groups = sort {
        my ($dir_a, $dir_b) = map {$_->file_specs->[0]->directory_id} ($a, $b);
        return ($dir_a cmp $dir_b);
    } @{$pdr->file_groups};
    $pdr->file_groups(\@sort_groups);
}
