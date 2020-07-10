=head1 NAME

PCFEntry - object for individual lines in ECS Process Control Files.

=head1 SYNOPSIS

=for roff
.nf

S4P::PCF::replace_directory($text, $lun, $new_directory);

pcf_processor PCFEntry($pcf_template_file, $pcf_output_file, $pcf_lun_map);

=head1 SEMI-PRIVATE METHODS

$entry = new S4P::PCFEntry;

$lun = $entry->lun_sequence;

$entry->lun($lun);

$entry->version($version);

$entry->fileref;

$entry->directory;

$entry->ur;

$entry->metpath;

$entry->parameter;

$entry->value;

=head1 DESCRIPTION

PCFEntry is a convenience object to describe lines from Process Control
Files.  It is used primarily by PCF.pm.

The semi-private methods include sprint, which returns a formatted string,
and parse, which parses a PCF line.  The rest are by and large simple 
attribute get/set methods,

The only other significant methods of interest are replace_directory and 
pcf_processor (which are scheduled to move to the PCF module).

=head2 delete

delete a given entry, identified by LUN, if the version is greater than the input version

=head2 replace

replaces the fileref, directory, ur, met in a given entry, identified by LUN.

=head2 replace_fileref

replaces the fileref field in a given entry, identified by LUN.

=head2 replace_directory

replaces the directory field in a given entry, identified by LUN.

=head2 replace_ur

replaces the UR field in a given entry, identified by LUN.

=head2 replace_version

replaces the version field in a given entry, identified by LUN.

=head2 pcf_processor

This is used by PGE triggering scripts to parse a PCF template, replacing 
certain entries with the desired filenames.

=head1 SEE ALSO

http://newsroom.hitc.com/sdptoolkit/primer/pc_overview.html#constructing_PCF,
PCF(3)

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=cut

################################################################################
# PCFEntry.pm,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

########################################################################
# ^REVISION HISTORY:
#
#	Baochun Ge (RDC), 12/17/98
#	added:
#	pcf_processor
#	get_from_pcf
#
#	as generic pcf processing routines to
#	replace PGE0*.pm and AIRSL*.pm modules.
#
#	Bryan Zhou, 08/20/2000
#	Added: delete, replace
# ^Y2K:
#	Certified Dateless by Lynnes on 08/10/1998
#
# ^OldSccsId: @(#)PCFEntry.pm	1.8 3/2/99
# SccsId: @(#)PCFEntry.pm	2.12 01/08/02

package S4P::PCFEntry;
use S4P;
use Class::Struct;
struct 'S4P::PCFEntry' => {
    lun => '$',
    version => '$',
    fileref => '$',
    directory => '$',
    ur => '$',
    metpath => '$',
    parameter => '$',
    value => '$'
};
1;

sub delete {
    my (%params) = @_;

    my $text    = exists $params{'text'}    ? $params{'text'}    : S4P::logger("FATAL", "No input text to replace.");
    my $lun     = exists $params{'lun'}     ? $params{'lun'}     : S4P::logger("FATAL", "No input lun to identify the entry.");
    #my $version = exists $params{'version'} ? $params{'version'} : S4P::logger("FATAL", "No input version(s) to identify the entry.");
    my $version = exists $params{'version'} ? $params{'version'} : "";
    #S4P::logger("INFO", "IN_LUN:$lun IN_VERSION:$version");

    my @lines = split('\n', $text);
    my @new_lines = ();
    foreach (@lines) {
        # When you find the lun we're looking for, parse the entry, all
        # verion that is greater than the input version will be deleted
	# from new pcf file and write the new entry out to the current string
        if (/^$lun\|/) {
	    #S4P::logger("INFO", "PCF_LINE:$_");
            my $entry = parse_entry($_);
	    my $ver = $entry->version();
	    #S4P::logger("INFO", "PCF_LUN:$lun PCF_VERSION:$ver");
	    if ($version eq "") {
		$_ = "\#".$_;
		push @new_lines, $_;
	    } elsif ($ver <= $version) {
		push @new_lines, $_;
		#S4P::logger("INFO", "PCF_LINE_SAVED:$_");
	    } else {
		$_ = "\#".$_;
		push @new_lines, $_;
	    }
        } else {
	    push @new_lines, $_;
	}
    }
    return join("\n", @new_lines) . "\n";
}

sub replace{
    my (%params) = @_;

    my $text     = exists $params{'text'}    ? $params{'text'}    : S4P::logger("FATAL", "No input text to replace.");
    my $lun      = exists $params{'lun'}     ? $params{'lun'}     : S4P::logger("FATAL", "No input lun to identify the entry.");
    #my $version  = exists $params{'version'} ? $params{'version'} : S4P::logger("FATAL", "No input version associated with lun $lun.");
    my $version  = exists $params{'version'} ? $params{'version'} : "";

    #S4P::logger("INFO", "REP_LUN:$lun REP_VERSION:$version");

    my @lines = split('\n', $text);
    my $add_new = 0;
    my @new_lines = ();
    foreach (@lines) {
        # When you find the lun we're looking for, parse the entry, change the
        # directory and write the new entry out to the current string
        if (/^$lun\|/) {
	    my $line  = $_;
            my $entry = parse_entry($_);
	    my $ver = $entry->version();
	    if (defined $ver) {
	    my $max_version = $ver if ($add_new == 0);
	    if ( (($version > $max_version) || ($version < $max_version && $version > $ver)) && $add_new == 0 ) {
		#S4P::logger("INFO", "VERSION:$version MAX_VERSION:$max_version VER:$ver");
		$add_new = 1;
		$entry = new S4P::PCFEntry;
		$entry->lun($lun);
		$entry->directory($params{'directory'}) if (exists $params{'directory'});
		$entry->fileref($params{'fileref'}) if (exists $params{'fileref'});
		$entry->ur($params{'ur'}) if (exists $params{'ur'});
		$entry->metpath($params{'metpath'}) if (exists $params{'metpath'});
		$entry->version($version);
		$_ = $entry->sprint;
		push @new_lines, $_;
		push @new_lines, $line;
		#S4P::logger("INFO", "A new entry added:$_");
	    } elsif ($ver == $version) {
		$add_new = 1;
		$entry->directory($params{'directory'}) if (exists $params{'directory'});
		$entry->fileref($params{'fileref'}) if (exists $params{'fileref'});
		$entry->ur($params{'ur'}) if (exists $params{'ur'});
		$entry->metpath($params{'metpath'}) if (exists $params{'metpath'});
		$_ = $entry->sprint;
		push @new_lines, $_;
		#S4P::logger("INFO", "After_REPLACING_LINE:$_");
	    } else {
		push @new_lines, $_;
		#S4P::logger("INFO", "No_REPLACING_LINE:$_");
	    }
	    } else {
		$entry->parameter($params{'parameter'}) if (exists $params{'parameter'});
		$entry->value($params{'value'}) if (exists $params{'value'});
		$_ = $entry->sprint;
		push @new_lines, $_;
	    }
	} else {
	    push @new_lines, $_;
	}
    }
    return join("\n", @new_lines) . "\n";
}

sub replace_directory {
    my ($text, $lun, $new_directory) = @_;
    my @lines = split('\n', $text);
    foreach (@lines) {
        next if /^#/;       # Skip comment lines
        # When you find the lun we're looking for, parse the entry, change the
        # directory and write the new entry out to the current string
        if (/^$lun/) {
             my $entry = parse_entry($_);
             $entry->directory($new_directory);
             $_ = $entry->sprint;
        }
    }
    return join("\n", @lines) . "\n";
}

sub replace_ur {
    my ($text, $lun, $new_ur) = @_;
    my @lines = split('\n', $text);
    foreach (@lines) {
        next if /^#/;       # Skip comment lines
        # When you find the lun we're looking for, parse the entry, change the
        # UR and write the new entry out to the current string
        if (/^$lun/) {
             my $entry = parse_entry($_);
             $entry->ur($new_ur);
             $_ = $entry->sprint;
        }
    }
    return join("\n", @lines) . "\n";
}

sub replace_fileref {
    my ($text, $lun, $new_fileref) = @_;
    my @lines = split('\n', $text);
    foreach (@lines) {
        next if /^#/;       # Skip comment lines
        # When you find the lun we're looking for, parse the entry, change the
        # filename and write the new entry out to the current string
        if (/^$lun/) {
             my $entry = parse_entry($_);
             $entry->fileref($new_fileref);
             $_ = $entry->sprint;
        }
    }
    return join("\n", @lines) . "\n";
}

sub replace_version {
    my ($text, $lun, $new_version) = @_;
    my @lines = split('\n', $text);
    foreach (@lines) {
        next if /^#/;       # Skip comment lines
        # When you find the lun we're looking for, parse the entry, change the
        # version and write the new entry out to the current string
        if (/^$lun/) {
             my $entry = parse_entry($_);
             $entry->version($new_version);
             $_ = $entry->sprint;
        }
    }
    return join("\n", @lines) . "\n";
}

sub parse_entry {
    my @fields = split '\|', $_[0];
    my $n_fields = scalar(@fields);

    # Index entries on logical unit number

    my $entry = new S4P::PCFEntry;
    $entry->lun($fields[0]);
    # Parameter / value type LUN
    if ($n_fields == 3) {
        $entry->parameter($fields[1]);
        $entry->value($fields[2]);
    }
    # File type LUN
    else {
        $entry->fileref($fields[1]);
        $entry->directory($fields[2]);
        $entry->ur($fields[4]);
        # 4th Field is reserved for future use
        $entry->metpath($fields[5]);
        $entry->version($fields[6]);
    }
    return $entry;
}
sub sprint {
    my $this = shift;
    # 4th field is reserved for future use
    my $reserved = '';
    if ($this->version) {
        return sprintf ("%s|%s|%s|%s|%s|%s|%s", $this->lun, $this->fileref, 
                  $this->directory, $reserved, $this->ur, $this->metpath, $this->version);
    }
    else {
        return sprintf "%s|%s|%s", $this->lun, $this->parameter, $this->value;
    }
}

######################
#
# ^NAME: pcf_processor
#
# ^DESCRIPTION:
#   This method opens a PCF, reads each line, decides whether to pass the
#   line through as-is or whether it needs to be processed based on whether
#   its LUN is in the pcf_lun_map structure, and then processes the line if
#   necessary.
#
# ^INPUT:
#   $template_pcf_file:     The template PCF filename
#
#   $output_pcf_file:       The output PCF filename
#
#   \%pcf_lun_map:         A reference to the pcf_lun_map structure,
#                            instantiated
#
# ^OUTPUT:
#   The PCF output file
#
sub pcf_processor {
    my $pkg = shift;
    my ($template_pcf_file, 
        $output_pcf_file, 
        $pcf_lun_map) = @_;


    # lun_separator defines the character that separates the pieces of
    # a LUN line
    my $lun_separator = "|";
 
    # open the input PCF template
    open(PCFIN, $template_pcf_file)
        or die "couldn't open the PCF template file $template_pcf_file";
    S4P::logger("INFO","Opened the PCF template");


    # open the output PCF
    open(PCFOUT, ">$output_pcf_file")
        or die "couldn't open output OPS PCF file $output_pcf_file\n";
    S4P::logger("INFO","Opened the output ops PCF file");

    # process the PCF line-by-line

    while (<PCFIN>) {

        chop($template_line = $_);

        # first, split it into pieces

        @line_parts = split(/\|/, $template_line);

        # is this LUN ***NOT*** in the structure? then just print it out

       unless($pcf_lun_map->{$line_parts[0]}) {
           print (PCFOUT "$template_line\n");
       }
       else {
           S4P::logger("INFO","Processing LUN $line_parts[0]");
 
           # else this LUN must be in the structure; process it

           # build the PCF line part by part

           # for readability, we'll reassign the hash values to scalars 1st
           $file_or_var = $pcf_lun_map->{$line_parts[0]}->{'file_or_var'};
           $dir_or_val  = $pcf_lun_map->{$line_parts[0]}->{'dir_or_val'};
           $metadata    = $pcf_lun_map->{$line_parts[0]}->{'metadata'};
           $version     = $pcf_lun_map->{$line_parts[0]}->{'version'};
           $number_of_sections 
                    = $pcf_lun_map->{$line_parts[0]}->{'number_of_sections'};

           # if the part you're holding has a value 'PCF' from the hash,
           # use the piece split from the PCF template line as-is

           if ( get_from_pcf PCFEntry($file_or_var) ) {
               $file_or_var = $line_parts[1];
           };
           # else $file_or_var stays the hash value


           if ( get_from_pcf PCFEntry($dir_or_val) ) {
               $dir_or_val = $line_parts[2];
           };
           # else $dir_or_val stays the hash value

           if ( get_from_pcf PCFEntry($metadata) ) {
               $metadata = $line_parts[4];
           };
           # else $metadata stays the hash value

           if ( get_from_pcf PCFEntry($version) ) {
               $version = $line_parts[6];
           };
           # else $version stays the hash value

           # decide how many sections to print in the newline: 3 or 7?
           $newline = ($number_of_sections == 3) ?
               join ($lun_separator, $line_parts[0], $file_or_var, $dir_or_val):
               join ($lun_separator, $line_parts[0], $file_or_var, $dir_or_val,
                      '', '', $metadata, $version); 
#                    '', $metadata, '', $version);

           print (PCFOUT "$newline\n");
			
        }; # end of unless-else
                               
    }; # end of PCFIN read

    # close the PCFs
    close(PCFIN);
    close(PCFOUT);

#   return success
    return 1;

}

#####################
#
# ^NAME: get_from_pcf
#
# ^DESCRIPTION:
#   This method takes a reference to a LUN hash key in a pcf_lun_map structure
#   and determines whether the value equals 'PCF', which means that the
#   value should be taken from the PCF template.
#
# ^INPUT:
#
#   $value:  $pcf_lun_map->{$lun}->{$key}
#
#   For example: 
#   This method might be called with 
#   $pcf_lun_map->{$line_parts[0]}->{$file_or_var}, which could
#   have a value of 'PCF' or could have a value of 'AIR10SCIinputfile.hdf'
#
# ^OUTPUT:
#
#  0: the value of the element was not 'PCF'
#  1: the value of the element was 'PCF'
#  
#############################################################################
sub get_from_pcf {
    my $pkg = shift;
    my $value = shift;

    # if the value is 'PCF', return true: 1, otherwise return false: 0.
    return ($value =~ '^PCF$') ? 1 : 0;
}
