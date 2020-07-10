=head1 NAME

MetFile.pm - a module for manipulating metfiles

=head1 SYNOPSIS

 use S4P::MetFile;

 %found_objects = S4P::MetFile::get_from_met($metfile,@needed_objects);    

 %found_objects = S4P::MetFile::get_from_met_string($string, @needed_objects);    

 $string = S4P::MetFile::get_from_met_string($string,@needed_objects);    

 @object = S4P::MetFile::objectify($attr,$val);    

 @grouped = S4P::MetFile::groupify($groupname,@group);

 S4P::MetFile::write_met($filename,@met);

 @met = S4P::MetFile::met_list(%met);

 $datetime=S4P::MetFile::get_start_datetime($metfile);

 $datetime=S4P::MetFile::get_stop_datetime($metfile);

 ($begin_date, $end_date) = 
    S4P::MetFile::get_datetime_range($metfile)

 ($begin_date, $end_date, $ra_lat, $ra_lon) = 
    S4P::MetFile::get_spatial_temporal_metadata($metfile)

 $odl = S4P::MetFile::xml2odl($xml, [$show_type]);

 $odl = S4P::MetFile::hdfeos2odl($hdf_file);

=head1 DESCRIPTION

get_from_met
This sub reads the metfile and extracts the values for the
  objects passed in the list of @needed_objects. It returns
  the hash of needed_object=>value.

objectify() takes an attribute/value pair and puts it into ODL format.
A list is returned with each element being a line of ODL

groupify() is passed a group of ODL objects and puts a GROUP=$groupname
and END_GROUP=$groupname around them.

write_met() takes a file name and a list of ODL lines and writes them
to the metfile.

met_list() takes a hash of attributes and values and generates a 
list where each element is a line of the MET file

get_start_datetime() pulls out the starting datetime from a metfile 
to be used by get_granule

get_stop_datetime() pulls out the stopping datetime from a metfile 
to be used by pge init.

get_datetime_range() returns the BeginningDateTime and EndingDateTime.

get_spatial_temporal_metadata returns, in order, the BeginningDateTime,
EndingDateTime, a reference to an array of latitudes and a reference to
an array of longitudes (from a GPolygon).

xml2odl converts a DataPool .xml file into a more or less standard
ODL form.

hdfeos2odl reads an HDF-EOS (v. 4) file and returns the core metadata object
(in ODL).

=head1 AUTHOR

Chris Lynnes (NASA/GSFC) and Daniel Ziskin, GMU.

=cut

################################################################################
# MetFile.pm,v 1.6 2015/08/26 12:37:18 mtheobal Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P::MetFile;
use S4P;
use strict;
no warnings "uninitialized";   # Suppress uninitialized variable warnings in pattern matching
1;

sub get_from_met {
    my $metfile = shift;
    my $string = read_metfile($metfile);
    return(get_from_met_string($string, @_));
}
sub read_metfile {
    my $metfile = shift;
    # read the file
    my $met_string = S4P::read_file($metfile);

    # If XML, convert to ODl style and continue
    # (appallingly inefficient but reduces code count)
    $met_string = xml2odl($met_string) if ($met_string =~ /^<\?xml/);

    return ($met_string);
}

sub get_from_met_string {
    my $metfilestring = shift;

    # Convert string into an array
    my @met=split(/\n/,$metfilestring);

    my %found_objects=();

    my $inobject=0;
    my $ininventory=0;
    my ($line, @line);
    my ($obj, $comp);

    foreach $line (@met) {
        $ininventory= 1 if ($line =~ /^\s*GROUP\s*=\s*INVENTORYMETADATA\s*$/i);
        $ininventory= 0 if ($line =~ /^\s*END_GROUP\s*=\s*INVENTORYMETADATA\s*$/i);
        next unless ($ininventory);

        # go through met file
        if ($line =~ /^\s*OBJECT\s*=\s*/i) {
            $obj=$';
            # pull out object=$obj

            $obj =~ s/\s*$//;
            $comp=uc($obj);
            #strip off trailing blanks and make UPPERCASE

            # is the OBJECT in the list of needed objects? If so, set the
            # flag $inobject=1

            @line = grep(/$comp/,@_);
            $inobject=1    if (@line);    
        }

        if (($inobject) && ($line =~ /^\s*VALUE\s*=\s*/i)) {
            $inobject=0;
            my $val=$';
            $val =~ s/\s*$//;
            $val =~ s/^\"//;
            $val =~ s/\"$//;
            $found_objects{$comp} = $val;
        }

        # reset $inobject even if no value is found
        $inobject=0 if (($inobject) && ($line =~ /^\s*END_OBJECT\s*=\s*$obj\s*$/i));
        
    }
    return (%found_objects);
}

sub objectify {
    my ($attr,$val)=@_;
    my @met;

    push(@met,"OBJECT=$attr");
    push(@met,"VALUE=\"$val\"");
    push(@met,"END_OBJECT=$attr");
    return (@met);
}

sub groupify {
    my($groupname,@group)=@_;
    
    my @grouped=("GROUP=$groupname");
    push(@grouped,@group);
    push(@grouped,"END_GROUP=$groupname");

    return (@grouped);
}

sub write_met {
    my($filename,@met)=@_;

    my $metstring=join("\n",@met);
    $metstring .= "\n";
    my $ret=S4P::write_file($filename,$metstring);
    # 1 for success  OR 0 for failure
    return $ret;
}

sub met_list {
    my(%met)=@_;
    my(@met);

    @met=('GROUP = INVENTORYMETADATA','GROUPTYPE = MASTERGROUP');
    my @datetime=();
    my @granule=();
    my @cdc=();
    my $attr;

    foreach $attr ('RANGEENDINGTIME','RANGEENDINGDATE','RANGEBEGINNINGTIME','RANGEBEGINNINGDATE') {
        push(@datetime,S4P::MetFile::objectify($attr,$met{$attr}));
    }
    push(@met,S4P::MetFile::groupify('RANGEDATETIME',@datetime));

    @granule=S4P::MetFile::objectify('LOCALGRANULEID',$met{'LOCALGRANULEID'});
    push(@met,S4P::MetFile::groupify('ECSDATAGRANULE',@granule));
    
    foreach $attr ('SHORTNAME','VERSIONID') {
        push(@cdc,S4P::MetFile::objectify($attr,$met{$attr}));
    }
    push(@met,S4P::MetFile::groupify('COLLECTIONDESCRIPTIONCLASS',@cdc));
    
    push(@met,'END_GROUP=INVENTORYMETADATA','END');

    return @met;
}

# pull out the a datetime from a metfile to be used by get_granule

sub get_datetime {
    my ($metfile, $which) = @_;
    my $string = read_metfile($metfile);
    return get_datetime_string($string, $which);
}
sub get_datetime_string {
    my ($string, $which) = @_;
    # which is either BEGINNING or ENDING
    my @get=('RANGE' . $which . 'DATE', 'RANGE' . $which . 'TIME',
        'CALENDARDATE','TIMEOFDAY');
    my $datetime;
    my %datetime=&get_from_met_string($string,@get) or return undef;
    if (exists $datetime{$get[0]}) {
        $datetime=$datetime{$get[0]}.'T'.$datetime{$get[1]};
    }
    elsif (exists $datetime{$get[2] }) {
        $datetime=$datetime{$get[2]}.'T'.$datetime{$get[3]};
    }
    else {
        return;
    }
    # MetFile time may or may not have a Z on end
    # Make sure there is one and only one.
    $datetime =~ s/Z*$/Z/;
    return $datetime;
}
# get_stop_datetime: get the stopping datetime from a metfile
sub get_start_datetime {
    get_datetime(shift, 'BEGINNING');
}
# get_stop_datetime: get the stopping datetime from a metfile
sub get_stop_datetime {
    get_datetime(shift, 'ENDING');
}
sub check_datetime {
    my $datetime = shift;
    return ($datetime =~ /\d\d\d\d-[01]\d-[0-3]\d[ T][0-2]\d:[0-5]\d:[0-5]\d.*\d*Z*/);
}
#################################################
# get_datetime_range:  
#     Returns $BeginningDateTime, $EndingDateTime
#################################################
sub get_datetime_range {
    my $metfile = shift;
    my $metstring = read_metfile($metfile) or return;
    my $begin = get_datetime_string($metstring, 'BEGINNING');
    my $end = get_datetime_string($metstring, 'ENDING');
    return ($begin, $end);
}

# get_spatial_temporal_metadata:  the most common metadata of interest:
#   BeginningDateTime, EndingDateTime, GPolygon
#   Returns ($BeginningDateTime, $EndignDateTime, \@latitudes, \@longitudes)
sub get_spatial_temporal_metadata {
    my $metfile = shift;

    # Read file once for metadata string
    my $metstring = read_metfile($metfile) or return;

    # GPolygon (BoundingBox to be added later)
    my (@latitude, @longitude);
    my %gpolygon = get_from_met_string($metstring, 'GRINGPOINTLATITUDE', 
        'GRINGPOINTLONGITUDE');
    # Remove surrounding parentheses and split on the commas.
    if (%gpolygon) {
        my $lat_str = $gpolygon{'GRINGPOINTLATITUDE'};
        my $long_str = $gpolygon{'GRINGPOINTLONGITUDE'};
        $lat_str =~ s/[()]//g;
        $long_str =~ s/[()]//g;
        @latitude = split(',', $lat_str);
        @longitude = split(',', $long_str);
    }
    my $begin = get_datetime_string($metstring, 'BEGINNING');
    my $end = get_datetime_string($metstring, 'ENDING');
    return ($begin, $end, \@latitude, \@longitude);
}

##############################################################
sub xml2odl {
    my $xml = shift;
    my $show_type = shift;
    # Look for ProducersMetaData object; read it and skip to end
    $xml =~ /<ProducersMetaData>(.*)<\/ProducersMetaData>/s;
    my $odl = $1;
    if (($odl) and ($odl !~ /\s*</)) {
        $odl =~ s/\n*$// ;
        my $last = (split /\n/,$odl)[-1] ;
        $odl .= "\n" ;
        chomp($last) ;
        $odl .= "END\n" unless ($last eq "END") ;
        return($odl) if ($odl) ;
    }
    my ($rh_core, $rh_sensor, $rh_measured_parameter, $rh_psa, $ra_pointers) = parse_xml($xml);
    return format_odl($rh_core, $rh_sensor, $rh_measured_parameter, $rh_psa, $ra_pointers, $show_type);
}
sub parse_xml {
    no warnings 'uninitialized';
    my $xml = shift;
    my @core = qw(DbID InsertTime LastUpdate ShortName VersionID 
        SizeMBECSDataGranule ReprocessingPlanned ReprocessingActual 
        LocalGranuleID DayNightFlag PGEVersion ZoneIdentifier
        ProductionDateTime LocalVersionID RangeEndingTime RangeEndingDate
        RangeBeginningTime RangeBeginningDate
    );
    my $attr;
    my (%core, %measured_parameter, %sensor, %psa);
    # Look for Core attributes
    foreach $attr(@core) {
        my ($val) = ($xml =~ m#<$attr>(.*?)</$attr>#i);
        $core{$attr} = $val if (defined $val);
    }
    # Get Platform/Instrument/Sensor hierarchy
    while ($xml =~ m#<Platform>(.*?)</Platform>#sg) {
        my $platform = $1;
        my ($platform_name) = ($platform =~ m#<PlatformShortName>(.*?)</PlatformShortName>#);
        while ($platform =~ m#<Instrument>(.*?)</Instrument>#sg) {
            my $instrument = $1;
            my ($inst_name) = ($instrument =~ m#<InstrumentShortName>(.*?)</InstrumentShortName>#);
            my ($opmode) = ($instrument =~ m#<OperationMode>(.*?)</OperationMode>#);
            $sensor{$platform_name}{$inst_name}{'opmode'} = $opmode if ($opmode);
            while ($instrument =~ m#<Sensor>(.*?)</Sensor>#sg) {
                my $sensor = $1;
                my ($sensor_name) = ($sensor =~ m#<SensorShortName>(.*?)</SensorShortName>#);
                push @{$sensor{$platform_name}{$inst_name}{'sensors'}}, $sensor_name;
            }
        }
    }

    # Find MeasuredParameter attributes
    while ($xml =~ m#<MeasuredParameterContainer>(.*?)</MeasuredParameterContainer>#sg) {
        my $mp = $1;
        my @attrs = qw(QAPercentMissingData QAPercentOutofBoundsData 
            QAPercentInterpolatedData QAPercentCloudCover
            AutomaticQualityFlag AutomaticQualityFlagExplanation 
            OperationalQualityFlag OperationalQualityFlagExplanation 
            ScienceQualityFlag ScienceQualityFlagExplanation);
        my %mp;
        my ($parameter) = ($mp =~ m#<ParameterName>(.*?)</ParameterName>#);
        foreach my $attr(@attrs) {
            my ($val) = ($mp =~ m#<$attr>(.*?)</$attr>#);
            $measured_parameter{$parameter}{$attr} = $val if (defined($val));
        }
    }

    # Go through PSAs
    while ($xml =~ m#<PSA>(.*?)</PSA>#sg) {
        my $psa = $1;
        my ($name) = ($psa =~ m#<PSAName>(.*)</PSAName>#s);
        my ($value) = ($psa =~ m#<PSAValue>(.*)</PSAValue>#s);
        $psa{$name} = $value;
    }

    # Find InputPointers
    my @input_pointers;
    while ($xml =~ m#<InputPointer>(.*?)</InputPointer>#sg) {
        push @input_pointers, $1;
    }

    # GPolygons
    my (@geo, @longitude, @latitude);
    my ($zone, $spatial_type) = ($xml =~ m#<HorizontalSpatialDomainContainer>(.*)<(BoundingRectangle|GPolygon)>#is);
    my ($zone_id) = ($zone =~ m#<ZoneIdentifier>(.*?)</ZoneIdentifier>#);
    $core{'ZoneIdentifier'} = $zone_id if ($zone_id);
    if ($spatial_type eq 'GPolygon') {
        while ($xml =~ m#<PointLongitude>(.*?)</PointLongitude>.*?<PointLatitude>(.*?)</PointLatitude>#sg) {
            push @longitude, $1;
            push @latitude, $2;
        }
        push @geo, @longitude, @latitude;
    }
    elsif ($spatial_type eq 'BoundingRectangle') {
        my %cardinal = ('West'=>0, 'East'=>1, 'South'=>2, 'North'=>3);

        while ($xml =~ m#<(.*?)BoundingCoordinate>(.*?)</.*?BoundingCoordinate>#sg) {
            $geo[$cardinal{$1}] = $2;
        }
    }
    $core{$spatial_type} = \@geo if @geo;

    if ($xml =~ m#<OrbitCalculatedSpatialDomainContainer>(.*?)
           <EquatorCrossingLongitude>(.*?)</EquatorCrossingLongitude>.*?
           <EquatorCrossingDate>(.*?)</EquatorCrossingDate>.*?
           <EquatorCrossingTime>(.*?)</EquatorCrossingTime>.*?
            </OrbitCalculatedSpatialDomainContainer>#msgx) {
        my $orbit_info = $1;
        $core{'EquatorCrossingLongitude'} = $2;
        $core{'EquatorCrossingDate'} = $3;
        $core{'EquatorCrossingTime'} = $4;
        if ($orbit_info =~ m#<OrbitNumber>(\d+)</OrbitNumber>#s) {
            $core{'OrbitNumber'} = $1;
        }
        elsif ($orbit_info =~ m#<StartOrbitNumber>(\d+)</StartOrbitNumber>#s) {
            $core{'StartOrbitNumber'} = $1;
            if ($orbit_info =~ m#<StopOrbitNumber>(\d+)</StopOrbitNumber>#s) {
                $core{'StopOrbitNumber'} = $1;
            }
        }
    }
    return (\%core, \%sensor, \%measured_parameter, \%psa, \@input_pointers);
}
sub format_odl {
    use strict;
    my ($rh_core, $rh_sensor, $rh_measured_parameter, $rh_psa, 
        $ra_input_pointers, $show_type) = @_;


    # Start off with boilerplate
    my @met = ('GROUP = INVENTORYMETADATA','GROUPTYPE = MASTERGROUP');

    # Collection Stuff
    my @group;
    push @group, format_odl_attr($show_type, 2, $rh_core, 'ShortName', 'STRING');
    push @group, format_odl_attr($show_type, 2, $rh_core, 'VersionID', 'INTEGER');
    push @met, map {'  ' . $_} groupify('COLLECTIONDESCRIPTIONCLASS', @group);

    # ECSDataGranule
    @group = ();
    foreach ('SizeMBECSDataGranule','ReprocessingPlanned','ReprocessingActual',
             'LocalGranuleID','ProductionDateTime', 'LocalVersionID', 
             'DayNightFlag') {
        push (@group, format_odl_attr($show_type, 2, $rh_core, $_)) 
            if exists $rh_core->{$_};
    }
    push @met, map {'  ' . $_} groupify('ECSDATAGRANULE', @group);

    # RangeDateTime
    @group = ();
    foreach ('RangeEndingTime','RangeEndingDate','RangeBeginningTime',
             'RangeBeginningDate') {
        push @group, format_odl_attr($show_type, 2, $rh_core, $_);
    }
    push @met, map {'  ' . $_} groupify('RANGEDATETIME', @group);

    # PGEVersion
    push @met, map {'  ' . $_} 
        groupify('PGEVERSIONCLASS', format_odl_attr($show_type, 2, $rh_core, 'PGEVersion'));

    # Measured Parameter
    my @qa_stats = qw(QAPercentMissingData QAPercentOutofBoundsData 
            QAPercentInterpolatedData QAPercentCloudCover);
    my @qa_flags = qw(AutomaticQualityFlag AutomaticQualityFlagExplanation 
                      ScienceQualityFlag ScienceQualityFlagExplanation
                      OperationalQualityFlag OperationalQualityFlagExplanation);
    if (%$rh_measured_parameter) {
        my $n_par = 0;
        my @mp_group;
        foreach my $par (sort keys %$rh_measured_parameter) {
            push @mp_group, '  OBJECT = MEASUREDPARAMETERCONTAINER';

            # Counter is used for "CLASS"
            $n_par++;

            # ParameterName
            push @mp_group, sprintf('%sCLASS = "%d"', ' ' x 4, $n_par);
            push @mp_group, format_odl_attr($show_type, 4, $par, 'ParameterName');
            my $rh_attr = $rh_measured_parameter->{$par};

            # QA Stats:  Indent only 2 as we will indent whole group later
            @group = ();
            foreach my $attr(@qa_stats) {
                push (@group,  format_odl_attr($show_type, 2, $rh_attr, 
                       $attr, 'INTEGER', $n_par)) if exists $rh_attr->{$attr};
            }
            push @mp_group, map {' ' x 4 . $_} groupify('QASTATS', @group);

            # QA Flags:  Indent only 2 as we will indent whole group later
            @group = ();
            foreach my $attr(@qa_flags) {
                push (@group,  format_odl_attr($show_type, 2, $rh_attr, 
                       $attr, 'STRING', $n_par)) if exists $rh_attr->{$attr};
            }
            push @mp_group, map {' ' x 4 . $_} groupify('QAFLAGS', @group);

            push @mp_group, '  END_OBJECT = MEASUREDPARAMETERCONTAINER';
        }
        @group = groupify( 'MEASUREDPARAMETER', @mp_group);
        push @met, map {'  ' . $_} @group;
    }

    # PSAs
    if (%$rh_psa) {
        my @psa_group;
        my $n_psa = 0;
        foreach my $psa(sort keys %$rh_psa) {
            push @psa_group, '  OBJECT = ADDITIONALATTRIBUTESCONTAINER';
            # Counter is used for CLASS
            $n_psa++;
            push @psa_group, sprintf('    CLASS = "%d"', $n_psa);
            push @psa_group, format_odl_attr($show_type, 4, $psa, 
                'ADDITIONALATTRIBUTENAME', 'STRING', $n_psa);
            my @group = (sprintf('  CLASS = "%d"', $n_psa));
            push @group, format_odl_attr($show_type, 2, $rh_psa->{$psa}, 
                'PARAMETERVALUE', 'STRING', $n_psa);
            push @psa_group, map {'    ' . $_}
                groupify('INFORMATIONCONTENT', @group);
            push @psa_group, '  END_OBJECT = ADDITIONALATTRIBUTESCONTAINER';
        }
        push @met, map {'  ' . $_} 
            groupify('ADDITIONALATTRIBUTES', @psa_group);
    }

    # Input Pointers
    if (@$ra_input_pointers) {
        my @odl = format_odl_attr($show_type, 2, $ra_input_pointers, 'InputPointer', 'STRING');
        push @met, map {'  ' . $_} groupify('INPUTGRANULE', @odl);
    }

    # Associated Sensor/Platform/Instrument (ASPI)
    if ($rh_sensor) {
        my $n = 1;
        foreach my $platform(sort keys %$rh_sensor) {
            foreach my $inst(sort keys %{$rh_sensor->{$platform}}) {
                foreach my $sensor(@{$rh_sensor->{$platform}->{$inst}->{'sensors'}}) {
                    my @aspi = ('  OBJECT = ASSOCIATEDPLATFORMINSTRUMENTSENSORCONTAINER', "    CLASS = \"$n\"");
                    push @aspi, format_odl_attr($show_type, 4, $platform, 'ASSOCIATEDPLATFORMSHORTNAME', 'STRING', $n);
                    push @aspi, format_odl_attr($show_type, 4, $inst, 'ASSOCIATEDINSTRUMENTSHORTNAME', 'STRING', $n);
                    push @aspi, format_odl_attr($show_type, 4, $sensor, 'ASSOCIATEDSENSORSHORTNAME', 'STRING', $n);
                    push ( @aspi, format_odl_attr($show_type, 4,
                        $rh_sensor->{$platform}->{$inst}->{'opmode'},
                        'OPERATIONMODE', 'STRING', $n) )
                        if $rh_sensor->{$platform}->{$inst}->{'opmode'};;
                    push (@aspi, '  END_OBJECT = ASSOCIATEDPLATFORMINSTRUMENTSENSORCONTAINER');
                    push @met, map {'  ' . $_} groupify('ASSOCIATEDPLATFORMINSTRUMENTSENSOR', @aspi);
                    $n++;
                }
            }
        }
    }

    my @zone_met;
    if (exists $rh_core->{'ZoneIdentifier'}) {
        @zone_met = map {'  ' . $_} groupify('ZONEIDENTIFIERCLASS', 
            format_odl_attr($show_type, 2, $rh_core, 'ZoneIdentifier') );
    }
    # Spatial Domain
    if ($rh_core->{'GPolygon'}) {
        my (@gring, @gring_grp);
        my $ra_geo = $rh_core->{'GPolygon'};
        my @longitude = splice(@$ra_geo, 0, scalar(@$ra_geo)/2);
        my @gpolygon_grp = ('OBJECT = GPOLYGONCONTAINER');
        push @gpolygon_grp, '  CLASS = "1"';
        my @seq = 1..scalar(@longitude);
        push @gring, format_odl_attr($show_type, 4, \@longitude, 'GRINGPOINTLONGITUDE', 'FLOAT', 1);
        push @gring, format_odl_attr($show_type, 4, $ra_geo, 'GRINGPOINTLATITUDE', 'FLOAT', 1);
        push @gring, format_odl_attr($show_type, 4, \@seq, 'GRINGPOINTSEQUENCENO', 'INTEGER', 1);
        @gring_grp = map {'  ' . $_} groupify('GRINGPOINT', @gring);
        splice(@gring_grp, 1, 0, '    CLASS = "1"');
        my @gring_exc = map {'  ' . $_} groupify('GRING', 
           format_odl_attr($show_type, 2, 'N', "EXCLUSIONGRINGFLAG", 'STRING', 1));
        splice(@gring_exc, 1, 0, '    CLASS = "1"');
        push(@gpolygon_grp, @gring_grp, @gring_exc,
            'END_OBJECT = GPOLYGONCONTAINER');
        push @met, map {'  '.$_} groupify('SPATIALDOMAINCONTAINER',
            map {'  '.$_} groupify('HORIZONTALSPATIALDOMAINCONTAINER',
                map {'  '.$_} groupify('GPOLYGON', @gpolygon_grp) ) );
    }
    if ($rh_core->{'BoundingRectangle'}) {
        my $ra_geo = $rh_core->{'BoundingRectangle'};
        # parse_xml always parses in this order
        my @cardinal = ('WEST','EAST','SOUTH','NORTH');
        my @odl = map {format_odl_attr($show_type, 2, $ra_geo->[$_], 
            $cardinal[$_] . 'BOUNDINGCOORDINATE', 'FLOAT')} 0..3;
        my @br_met =  map {'  '.$_} groupify('BOUNDINGRECTANGLE', @odl);
        unshift (@br_met, @zone_met) if (@zone_met);
        push @met, map {'  '.$_} groupify('SPATIALDOMAINCONTAINER',
            map {'  '.$_} groupify('HORIZONTALSPATIALDOMAINCONTAINER', @br_met) );
    }

    # Orbital Info
    if ($rh_core->{'EquatorCrossingDate'}) {
        my @odl = ('OBJECT = ORBITCALCULATEDSPATIALDOMAINCONTAINER');
        push @odl, '  CLASS = "1"';
        push @odl, format_odl_attr($show_type, 2, $rh_core, 'EquatorCrossingDate', 'STRING', 1);
        push @odl, format_odl_attr($show_type, 2, $rh_core, 'EquatorCrossingTime', 'STRING', 1);
        foreach my $orbit_attr('OrbitNumber', 'StartOrbitNumber', 'StopOrbitNumber') {
            push @odl, format_odl_attr($show_type, 2, $rh_core, $orbit_attr, 'INTEGER', 1)
                if ($rh_core->{$orbit_attr});
        }
        push @odl, format_odl_attr($show_type, 2, $rh_core, 'EquatorCrossingLongitude', 'FLOAT', 1);
        push @odl, 'END_OBJECT = ORBITCALCULATEDSPATIALDOMAINCONTAINER';
        push (@met, map {'  ' . $_} 
            groupify('ORBITCALCULATEDSPATIALDOMAIN', @odl) );
    }

    # Correct groupify results while staying backward compatible
    map {s/GROUP=/GROUP = /} @met;
    push (@met, "END_GROUP = INVENTORYMETADATA");
    return join("\n", @met, '');
}
# Subroutine to format a single attribute in ODL.
sub format_odl_attr {
    no warnings 'uninitialized';
    my ($show_type, $indent, $r_val, $attr, $val_type, $class) = @_;
    my ($val, $num_val);
    # Value can be passed in as a simple scalar...
    if (! ref $r_val) {
        $val = $r_val;
        $num_val = 1;
    }
    # ...or a reference to a hash in which we need to look it up
    elsif (ref $r_val eq 'HASH') {
        $val = $r_val->{$attr};
        $num_val = 1;
    }
    # ...or a reference to an array which we need to pre-format
    else {
        $num_val = scalar(@$r_val);
        my $join_str = ($val_type eq 'STRING') ? '", "' : ', ';
        my $string = join($join_str, @$r_val);
        $string = '"' . $string . '"' if ($val_type eq 'STRING');
        $val = '(' . $string . ')';
        $val_type = 'VERBATIM';
    }
    # Try to guess $val_type if it is not specified
    unless ($val_type) {
        my $t_val = ($num_val > 1) ? $val->[1] : $val;
        if ($t_val =~ /^\d\d\d\d-[01]\d-[0-3]\d[ T][0-2]\d:[0-5]\d:[0-5]\d/) {
            $val_type = 'TIME';
        }
        elsif ($t_val =~ /^\d\d\d\d-[01]\d-[0-3]\d$/) {
            $val_type = 'DATE';
        }
        elsif ($t_val =~ /^-*[0-9]+\.[0-9]+$/) {
            $val_type = 'FLOAT';
        }
        elsif ($t_val =~ /^-*[0-9]+$/) {
            $val_type = 'INTEGER';
        }
        else {
            $val_type = 'STRING';
        }
    }
    # Convert everything to uppercase for consistency
    $attr = uc($attr);
    my @string = ("OBJECT = $attr");
    push (@string, sprintf('  CLASS = "%d"', $class)) if $class;
    push (@string, sprintf('  NUM_VAL = %d', $num_val));
    # (Is this first branch fossil code?)
    if (ref $val) {
        if ($val_type ne 'INTEGER' && $val_type ne 'FLOAT') {
            push (@string, '  VALUE = ("' . join('","', @$val) . '")');
        }
        else {
            push (@string, '  VALUE = (' . join(',', @$val) . ')');
        }
    }
    else {
        if ($val_type eq 'TIME') {
            my ($date, $time) = split(' ', $val);
            # Integerize seconds if possible
            $time =~ s/\.0+Z$/Z/; 
            push @string, sprintf('  VALUE = "%sT%sZ"', $date, $time);
        }
        elsif ($val_type eq 'DATE' || $val_type eq 'STRING') {
            push (@string, sprintf('  VALUE = "%s"', $val));
        }
        else {
            push (@string, sprintf('  VALUE = %s', $val));
        }
    }
#   push (@string, sprintf('    TYPE = "%s"', $val_type));
    push (@string, "END_OBJECT = $attr");
    return map {' ' x $indent . $_} @string;
}

sub hdfeos2odl ($) {
    my $file = shift;

    # Open up an executable file handle for ncdump
    # N.B.:  HDF binary directory must be in your PATH!
    unless ( open (NCDUMP, "ncdump -h $file|") ){
        S4P::logger('ERROR', "Cannot run ncdump on $file: $!");
        return;
    }

    # Slurp in ncdump header output
    local ($/) = undef;
    my $header = <NCDUMP>;
    close NCDUMP;

    # Find CoreMetadata in output
    my ($core_met) = ($header =~ m/:CoreMetadata[\._]?0?\s*=\s*"(.*?"\s*END\\n")/is);
    unless ($core_met) {
        S4P::logger('ERROR', "Cannot find core_met in ncdump output from file $file");
        return;
    }

    # Strip extraneous characters
    $core_met =~ s/\n\s*"/\n/gs;
    $core_met =~ s/\\n",*//gs;
    $core_met =~ s/\\"/"/gs;

    return $core_met;    
}
