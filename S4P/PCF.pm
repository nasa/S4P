=head1 NAME

PCF.pm - Perl object for reading and writing Process Control Files

=head1 SYNOPSIS

=for roff
.nf

use S4P::PCF;
$pcf = S4P::PCF::read_pcf(filename);

$pcf->text($text);
$text = $pcf->text;
%log_files = %{$pcf->log_files};
%files = %{$pcf->product_input_files};
%files = %{$pcf->product_output_files};
%files = %{$pcf->support_input_files};
%files = %{$pcf->support_output_files};
%files = %{$pcf->intermediate_input_files};
%files = %{$pcf->intermediate_output_files};
%files = %{$pcf->temporary_i_o};
%files = %{$pcf->output_met_files};
%parms = %{$pcf->user_runtime_parameters};
%granules = %{$pcf->product_granules};

@values = get_by_lun($lun);
($parm1, $parm2, $parm3, ...) = get_shell_parms($lun1, $lun2, $lun3, ...);

=head1 SEMI-PRIVATE METHODS

$pcf = new S4P::PCF('pathname'=>$pathname, 'text'=>text);
$pcf->read_file;
$pcf->parse;
$pcf->production_run_id($prid);
$prid = $pcf->production_run_id;
$pcf->software_id($prid);
$prid = $pcf->software_id;

=head1 DESCRIPTION

The PCF object is used for reading EOSDIS Core System (ECS) Process Control 
Files (PCF) in order to run PGEs, and for writing PCFs as part of the 
triggering process.

=head2 read_pcf

Reads a Process Control File and creates (and returns) a PCF object.
This should be used for PCFs that already exist.

=head2 text

Allows setting/getting the full text of the PCF.  This is useful for
replacing individual entries in the PCF (see L<PCFEntry:replace_directory>).

=head2 output_met_files, product_output_files

These methods return references to hashes. The hash is indexed by the LUN.  
The values are whitespace separated LISTS of metadata or data files.
This is because you may have several files with the same lun, but different
"versions".

=head2 product_input_files

This method is similar to product_output_files, but with a key difference.
The hash index is $lun.$version, or the LUN concatenated with the version, with
a dot in between.  We retain the version in the hash because it affects the 
rules allowing us to clean data off the system.  The PGE(1) module uses
to set the "coffin nails" for a given file in the Granule Tracking database.
It is often the case that a only some of the granules for a given LUN can be
cleaned because we need the others for processing of other granules.

=head2 support_input_files, intermediate_input_files

These methods correspond to B<product_input_files>, but for the SUPPORT and
INTERMEDIATE sections of the PCF.

=head2 support_output_files, intermediate_output_files

These methods correspond to B<product_input_files>, but for the SUPPORT and
INTERMEDIATE sections of the PCF.

=head2 log_files

This returns a reference to a hash of the log files, indexed on the type of
log:  status, report or user.

=head2 product_granules

This method returns a reference to a hash of product I<granules>.  
The hash key is the metadata file and the value is an anonymous array
of science files.

=head2 user_runtime_parameters

These methods return references to hashes. The hash is indexed by the LUN.  
The value is the parameter values corresponding to that LUN.

=head2 get_by_lun

Returns an array of values corresponding to that the lun $lun. For 
file entries, it returns the full pathnames; for user defined runtime
parameters, it returns the parameter value. If the LUN doesn't exist,
it returns undef.

=head2 get_shell_parms

Returns a list of PCF parameters (full pathnames or parameter values) for
each LUN listed. This only works if there is only one "version" per LUN.
For multiversion LUNs, use get_by_lun() instead.

=head1 BUGS

The filenames for different versions of the lun are in no particular
order when they are put in the list.

=head1 AUTHOR

Chris Lynnes, NASA/GSFC, Code 610.2

=head1 SEE ALSO

http://newsroom.hitc.com/sdptoolkit/primer/pc_overview.html#constructing_PCF,
L<PCFEntry(3)>

=head1 TO DO

Error handling

=cut

################################################################################
# PCF.pm,v 1.3 2006/11/24 15:51:26 lynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P::PCF;
    use S4P;
    use S4P::PCFEntry;
    use S4P::PDR;
    use strict;
    use Class::Struct;
    struct 'S4P::PCF' => {
        pathname => '$',
        text => '$',
        sections => '$',
        production_run_id => '$',
        software_id => '$'
    };
    1;

sub read_pcf {
    my $filename = shift;
    my $pcf = S4P::PCF->new();
    $pcf->pathname($filename);
    if (! $pcf) {
        S4P::logger("ERROR", "Failed to create PCF");
        return 0;
    }
    if (! $pcf->read_file) {
        S4P::logger("ERROR", "Failed to read PCF");
        return 0;
    }
    if (! $pcf->parse) {
        S4P::logger("ERROR", "Failed to parse PCF");
        return 0;
    }
    return $pcf;
}

sub read_file {
    my $this=shift;

    # Get full pathname or quit
    my $pathname = $this->pathname;
    if (! $pathname) {
        S4P::logger("FATAL", "No pathname in S4P::PCF::read_file, error=$!");
        return 0;
    }

    # Read it and set in one fell swoop
    my $contents = S4P::read_file($pathname);
    $this->text( $contents ) if $contents;
    return ($contents ? 1 : 0);
}

sub parse {
    my $this = shift;

    # If file is not yet read, read it
    if (! $this->text) {
       $this->read_file or return 0;
    }
    my @text_sections = split(/\n\?\s*/, $this->text);
    my $text_section;
    my %sections;
    my ($expected, $errors);
    shift @text_sections;  # Skip the first one:  just comments
    foreach $text_section(@text_sections) {
        my %section;
        $text_section .= "\n";
        $text_section =~ m/^(.*?)\n/s;
        my $name = $1;
        $name =~ s/\s*$//;
        if ($text_section =~ /^SYSTEM RUNTIME PARAMETERS/) {
            $text_section =~ m/\n([0-9]+).*\n([0-9]+)/s;
            $this->production_run_id($1);
            $this->software_id($2);
        }
        else {
            $text_section =~ m/\n!\s*(\S+)/s;
            $section{'default_path'} = $1;
            my @fields;
            my %entries;
            my ($entry, $entry_index);
            while ($text_section =~ m/\n([0-9]+.*?)(?=\n)/sg) {
                $entry = S4P::PCFEntry::parse_entry($1);
                # Index entries on logical unit number
                $entry_index = ($entry->version) 
                             ? $entry->lun . "." . $entry->version 
                             : $entry->lun;
                $entries{$entry_index} = $entry;
            }
            $section{'entries'} = \%entries;
            $sections{$name} = \%section;
        }
    }
    $errors = 0;
    foreach $expected('PRODUCT OUTPUT FILES', 'SUPPORT OUTPUT FILES',
                      'PRODUCT INPUT FILES', 'SUPPORT INPUT FILES', 
                      'INTERMEDIATE INPUT', 'INTERMEDIATE OUTPUT', 
                      'TEMPORARY I/O', 'USER DEFINED RUNTIME PARAMETERS') {
        if (! exists $sections{$expected}) {
            S4P::logger("ERROR", 
                        "PCF parsing failure: cannot find $expected section");
            $errors++;
        }
    }
    if ($errors == 0) {
        $this->sections(\%sections);
        return 1;
    }
    else {
        return 0;
    }
}
sub log_files {
    my $this = shift;
    if (! $this->sections) {
        $this->parse or return undef;
    }

    # Get the hash representing the section for the support output files
    my %support_output_files = %{$this->sections->{'SUPPORT OUTPUT FILES'}};

    my $default_path = $support_output_files{'default_path'};
    my %entries = %{$support_output_files{'entries'}};

    my %logs = ('status'=>'10100.1', 'report'=>'10101.1', 'user'=>'10102.1');
    my $ltype;
    my $directory;
    my $entry;
    foreach $ltype(keys %logs) {
        $entry = $entries{$logs{$ltype}};
        $directory = $entry->directory ? $entry->directory : $default_path;

        # Replace the LUN with the pathname
        $logs{$ltype} = ($directory ? "$directory/" : "") . $entry->fileref;
    }
    return \%logs;
}
sub support_output_files {
    my $this = shift;
    return $this->product_files('SUPPORT OUTPUT FILES','fileref', 0);
}
sub support_input_files {
    my $this = shift;
    return $this->product_files('SUPPORT INPUT FILES','fileref', 0);
}
sub product_output_files {
    my $this = shift;
    return $this->product_files('PRODUCT OUTPUT FILES','fileref', 0);
}
sub product_input_files {
    my $this = shift;
    return $this->product_files('PRODUCT INPUT FILES','fileref', 1);
}
sub intermediate_input_files {
    my $this = shift;
    return $this->product_files('INTERMEDIATE INPUT','fileref', 1);
}
sub intermediate_output_files {
    my $this = shift;
    return $this->product_files('INTERMEDIATE OUTPUT','fileref', 1);
}
sub temporary_i_o {
    my $this = shift;
    return $this->product_files('TEMPORARY I/O','fileref', 1);
}
sub user_runtime_parameters {
    my $this = shift;
    return $this->product_files('USER DEFINED RUNTIME PARAMETERS','fileref', 1);
}
# Same as product_output_files; retained for backward compatibility
sub output_data_files {
    my $this = shift;
    return $this->product_output_files;
}
sub output_met_files {
    my $this = shift;
    return $this->product_files('PRODUCT OUTPUT FILES','metpath', 0);
}
# Same as product_input_files; retained for backward compatibility
sub input_data_files {
    my $this = shift;
    return $this->product_input_files;
}
sub product_files {
    my ($this, $section, $output_type, $use_version) = @_;

    if (! $this->sections) {
        $this->parse or return undef;
    }

    # Get the hash representing the section for the product output files
    my %product_files = %{$this->sections->{$section}};
    my $default_path = $product_files{'default_path'};
    my %entries = %{$product_files{'entries'}};
    my ($r_entry, $index);
    my %filenames;  # Initialize the array

    foreach $r_entry(values %entries) {
        if ( $section eq 'USER DEFINED RUNTIME PARAMETERS' ) {
            $index = $r_entry->lun;
            $filenames{$index} = $r_entry->value;
        } else {
            $index = $use_version ? ($r_entry->lun . "." . $r_entry->version)
                                   : $r_entry->lun;
            next if ($r_entry->fileref =~ 'asciidump');  # Vestigial
            if ($filenames{$index}) {
                $filenames{$index} .= " " . pcf_pathname($r_entry,
                    $output_type, $default_path);
            }
            else {
                $filenames{$index} = pcf_pathname($r_entry, $output_type,
                    $default_path);
            }
        }
    }

    return \%filenames;
}
sub product_granules {
    my ($this, $section) = @_;
    if (! $this->sections) {
        $this->parse or return undef;
    }

    # Get the hash representing the section for the product output files
    my %product_files = %{$this->sections->{$section}};
    my $default_path = $product_files{'default_path'};
    my %entries = %{$product_files{'entries'}};
    my ($r_entry, %granules);

    # Loop through entries, indexing them on metfile
    # Multi-version luns that represent the same granule will have the
    # same metfile.  Multi-version luns that are different granules will
    # have different metfiles.
    foreach $r_entry(values %entries) {
        next if ($r_entry->fileref =~ 'asciidump');  # Vestigial
        my $metfile = pcf_pathname ($r_entry, 'metpath', $default_path);
        my $scifile = pcf_pathname ($r_entry, 'fileref', $default_path);
        push(@{$granules{$metfile}}, $scifile);
    }
    # Access as: $rh_granule->{$metfile}->[$i]
    return \%granules;
}
sub pcf_pathname {
    my ($r_entry, $output_type, $default_path) = @_;
    my $filename;

    # Old Toolkit version, the default path was ignored in case of blank met
    # New one, it will look at the default path

    $filename = $r_entry->directory ? $r_entry->directory : $default_path;
    # Add trailing slash if necessary
    $filename .= '/' if ($filename !~ m/\/$/); 
    
    if ($output_type =~ /^met/) {
        $filename .= ($r_entry->metpath) ? $r_entry->metpath 
                                         : $r_entry->fileref . ".met";
    }
    else {
        $filename .= '/' if ($filename !~ m/\/$/); 
        $filename .= $r_entry->fileref;
    }
    return $filename;
}

sub output_file_pdr {
    my $this = shift;
    my $r_lun_esdt_map = shift;

    if (! $this->sections) {
        $this->parse or return undef;
    }

    # Get the hash representing the section for the product output files
    my %product_output_files = %{$this->sections->{'PRODUCT OUTPUT FILES'}};
    my $default_path = $product_output_files{'default_path'};
    my %entries = %{$product_output_files{'entries'}};
    my $r_entry;
    my @files;
    my ($esdt_version, $esdt, $version);

    my $pdr = S4P::PDR::create();
    foreach $r_entry(values %entries) {
        @files = ();
        # Get ESDT:Version from stuff read in from config file
        $esdt_version = $r_lun_esdt_map->{$r_entry->lun};
        ($esdt, $version) = split (':',$esdt_version);

        next if ($r_entry->fileref =~ 'asciidump');  # Obsolete but relict
        push @files, pcf_pathname($r_entry, 'metpath', $default_path);
        push @files, pcf_pathname($r_entry, 'fileref', $default_path);
        $pdr->add_file_group($esdt, $version, @files);
    }
    return $pdr;
}

sub get_by_lun {

    my $lun = shift;

    my $pcf_name = $ENV{'PGS_PC_INFO_FILE'};
    my $pcf = S4P::PCF::read_pcf($pcf_name) or
              S4P::perish(1, "Cannot read/parse PCF $pcf_name: $!");

    my @results = ();

    my %product_input_files       = %{$pcf->product_input_files};
    my %product_output_files      = %{$pcf->product_output_files};
    my %support_input_files       = %{$pcf->support_input_files};
    my %support_output_files      = %{$pcf->support_output_files};
    my %intermediate_input_files  = %{$pcf->intermediate_input_files};
    my %intermediate_output_files = %{$pcf->intermediate_output_files};
    my %user_runtime_parameters   = %{$pcf->user_runtime_parameters};

    my %all_hash = (%product_input_files, %product_output_files,
                    %support_input_files, %support_output_files,
                    %intermediate_input_files, %intermediate_output_files,
                    %user_runtime_parameters);

    foreach my $key ( keys %all_hash ) {
        if ( $key =~ /^$lun/ ) {
            push(@results, $all_hash{$key});
        }
    }

    if ( scalar(@results) == 0 ) {
        return undef;
    } else {
        return @results;
    }
}

sub get_shell_parms {

    my @luns = @_;

    my @results = ();

    my $pcf_name = $ENV{'PGS_PC_INFO_FILE'};
    my $pcf = S4P::PCF::read_pcf($pcf_name) or
              S4P::perish(1, "Cannot read/parse PCF $pcf_name: $!");

    foreach my $lun ( @luns ) {
        my @items = S4P::PCF::get_by_lun($lun);
        foreach my $item (@items) {
        }
        if ( ! @items ) {
            push(@results, undef);
        }
        if ( scalar(@items) == 1 ) {
            push(@results, $items[0]);
        } else {
            push(@results, @items);
        }
    }

    return @results;

}
