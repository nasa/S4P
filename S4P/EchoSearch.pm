=head1 NAME

EchoSearch - A class to search ECHO catalog

=head1 SYNOPSIS

use S4P::EchoSearch
my $search = S4P::EchoSearch->new();
my $hits = $search->searchCollection( DATASET => 'MOD02SSH' );
my $result = $search->searchGranule( DATASET => 'MOD02SSH', VERSION => 5,
BEGIN_DATE => '2007-01-01' ); 

=head1 DESCRIPTION

=head1 AUTHOR

M. Hegde, ADNET Systems Inc

=cut

package S4P::EchoSearch;
use Math::Trig;
use SOAP::Lite;
use XML::LibXML;
use Sys::Hostname;
use Net::FTP;
use vars '$AUTOLOAD';

################################################################################

=head2 Constructor

Description:
    Constructs the object for searching ECHO.

Input:
    Accepts optional arguments: ECHO user name, password, URIs for web services.

Output:
    Returns S4P::EchoSearch object

Author:
    M. Hegde
    
=cut

sub new
{
    my ( $class, %arg ) = @_;
    my $search = {};
    
    $search->{_error} = '';
    $search->{_login} = 0;
    
    $search->{user} = defined $arg{USER} ? $arg{USER} : 'guest';
    $search->{pass} = defined $arg{PASSWORD} ? $arg{PASSWORD} : 'guest';
    $search->{uri}{echo} = defined $arg{ECHO_URI}
        ? $arg{ECHO_URI} : 'http://echo.nasa.gov/';
    $search->{uri}{proxy} = defined $arg{PROXY_URI}
        ? $arg{PROXY_URI} : 'http://api.echo.nasa.gov/';
    $search->{debug} = defined $arg{DEBUG} ? $arg{DEBUG} : 0;
    return bless( $search, $class );
}

################################################################################

=head2 getDateElement

Description:
    Reformats the date-time (YYYY-MM-DD hh:mm:ss) to ECHO's date-time format
    (<Date YYYY="" MM="" DD="" HH="" MI="" SS="")
    
Input:
    Date in YYYY-MM-DD hh:mm::ss format.
    
Output:
    Return the date in ECHO format or undef.
    
Author:
    M. Hegde
    
=cut

sub getDateElement
{
    my ( $date ) = @_;
    $date =~ s/T/ /;
    $date =~ s/Z$//;
    my ( $year, $mon, $day, $hh, $mm, $ss ) = 
        ($date =~ /(\d{4})-(\d{2})-(\d{2})(?: (\d{2}):(\d{2}):(\d{2}))?/ );
    return undef unless ( defined $year && defined $mon && defined $day );
    my $string = qq(<Date YYYY="$year" MM="$mon" DD="$day" );
    $string .= qq(HH="$hh" MI="$mm" SS="$ss" )
        if ( defined $hh && defined $mm && defined $ss );
    $string .= "/>";
    return $string;
}

################################################################################

=head2 searchCollection

Description:
    Returns a boolean indicating whether a collection is found in ECHO.
    
Input:
    Accepts the collection's short name and version ID.
    
Output:
    1/0 => Collection found/not found.
    
Author:
    M. Hegde
    
=cut

sub searchCollection
{
    my ( $self, %arg ) = @_;
    unless ( $self->loggedIn() ) {
        print STDERR "searchCollection(): not logged in!";
        return 0;
    }
    my $echoUri = $self->getEchoUri();
    my $proxyServer = $self->getProxyServer();
    my $query = qq(
<s0:query xmlns:s0=\"$echoUri\"><![CDATA[<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE query SYSTEM "$proxyServer/echo/dtd/IIMSAQLQueryLanguage.dtd">
      <query>
        <for value="collections"/>
        <dataCenterId>DATA_CENTER_ID</dataCenterId>
        <where>
            <collectionCondition>
                <shortName><value>'$arg{DATASET}'</value></shortName>
            </collectionCondition>
        </where>
      </query>
    ]]>
</s0:query>
);
    my $dataCenterId = defined $arg{DATA_CENTER_ID} ? qq(<value>$arg{DATA_CENTER_ID}</value>) : qq(<all />);
    $query =~ s/DATA_CENTER_ID/$dataCenterId/;
    my $queryElement = SOAP::Data->type( xml => $query );
    my $queryResultTypeElement = $self->soapEchoData( NAME => 'queryResultType',
        TYPE => '', VALUE => 'HITS' );    
    my $iteratorSizeElement = $self->soapEchoData( NAME => 'iteratorSize',
        TYPE => 'int', VALUE => 0 );
    my $cursorElement = $self->soapEchoData( NAME => 'cursor',
        TYPE => 'int', VALUE => 0 );
    my $maxResultElement = $self->soapEchoData( NAME => 'maxResults',
        TYPE => 'int', VALUE => 0 );
    my $metadataAttributeElement = $self->soapEchoData(
        NAME => 'metadataAttributes', TYPE => '', VALUE => '' );
    my $som = SOAP::Lite->uri( $self->getEchoUri() )
        ->proxy( $self->getProxyUri() . 'CatalogServicePortImpl',
            timeout => '300' )
        ->ExecuteQuery( $self->getTokenElement(), $queryElement,
            $queryResultTypeElement, $iteratorSizeElement, $cursorElement,
            $maxResultElement, $metadataAttributeElement);

    if ( $som->fault ) {
        $self->{_error} = "Error executing catalog query: " 
            . $som->fault->{faultstring};
        return 0;
    }
    return $som->valueof( '//Hits/Size' );
}

my $getBoundary = sub {
    my ( $doc ) = @_;
    my $xpath = 'SpatialDomainContainer/HorizontalSpatialDomainContainer/'
        . 'GPolygon/Boundary/Point';
        my $box = [];
    foreach my $point ( $doc->findnodes( $xpath ) ) {
        my $latNode = $point->getChildrenByTagName( 'PointLatitude' );
        my $lonNode = $point->getChildrenByTagName( 'PointLongitude' );
        push( @$box, "$latNode", "$lonNode" );
    }
    return $box;
};

my $rearrangeBoundary = sub {
    my ( $box ) = @_;
    my $newBox = [ @$box[0], @$box[1], @$box[2], @$box[3], @$box[6], 
        @$box[7], @$box[4], @$box[5] ];
    return $newBox;
};

my $doesOverlap = sub {

    my ( $Polygon1, $Polygon2, $opt_d ) = @_;

    # Derefernece the Input arrays

    my @Polygon1 = @$Polygon1;
    my @Polygon2 = @$Polygon2;


    # Even number points of Polygon Array are assumed to be Latitudes. Build a Latitude only array
    # that progresses in a clockwise manner to describe the polygon (used later in the fine scale checks)
    # This means switching the last to points to acheive the smooth clockwise rotation

    my @Lat1=($Polygon1[0],$Polygon1[2],$Polygon1[6],$Polygon1[4]);
    my @Lat2=($Polygon2[0],$Polygon2[2],$Polygon2[6],$Polygon2[4]);

    # Find the Max Min Latitudes for Polygon 1.

    my $MaxLat1=-90.0;
    my $MinLat1=90.0;
    for my $i (@Lat1) {
        $MaxLat1 = $i if ($MaxLat1 < $i);
        $MinLat1 = $i if ($MinLat1 > $i);
    }

# Find the Max Min Latitudes for Polygon 2.

    my $SuperMaxLat=$MaxLat1;
    my $SuperMinLat=$MinLat1;

    my $MaxLat2=-90.0;
    my $MinLat2=90.0;
    for my $i (@Lat2) {
        $MaxLat2 = $i if ($MaxLat2 < $i);
        $MinLat2 = $i if ($MinLat2 > $i);
        $SuperMaxLat = $i if ($SuperMaxLat < $i);
        $SuperMinLat = $i if ($SuperMinLat > $i);
    }

    if ( $opt_d ) {
        print "\n    Intersection Report\n";
        print "\n              First Bounding Box                           Second Bounding Box\n";
        printf "    %7.3f,%8.3f --- %7.3f,%8.3f        %7.3f,%8.3f --- %7.3f,%8.3f\n",
               $Polygon1[0],$Polygon1[1],$Polygon1[2],$Polygon1[3],$Polygon2[0],$Polygon2[1],$Polygon2[2],$Polygon2[3];
        printf "    %7.3f,%8.3f --- %7.3f,%8.3f        %7.3f,%8.3f --- %7.3f,%8.3f\n",
               $Polygon1[4],$Polygon1[5],$Polygon1[6],$Polygon1[7],$Polygon2[4],$Polygon2[5],$Polygon2[6],$Polygon2[7];
    }

    # If No Overlap in Latitude ( with 3 degrees of slop) ... return a false and exit

    if ( $MaxLat2+3.0 < $MinLat1-3.0 ) {
        return "No Overlap (Coarse Latitude)";
    } elsif ( $MaxLat1+3.0 < $MinLat2-3.0 ) {
        return "No Overlap (Coarse Latitude)";
    }

    # Check for Longitude overlap ..
    # Assume Polygons are defined West to East .and that the range of longitude values is -180 to 180.

    # Check if Polygon1 crosses the -180/180 Discontinuity ( Polygon indices 1 & 5 > indices 3 7 )

    my $Offset1=0.0;
    if ( $Polygon1[1] > $Polygon1[3] || $Polygon1[1] > $Polygon1[7] || $Polygon1[5] > $Polygon1[3] || $Polygon1[5] > $Polygon1[7] ) {

        # .... Polygon 1 crosses discontinuity ... need to extend the range of the longitude for negative longitudes by adding 360.
        # .... Also keep track of how much extension was required in case a normal western hemisphere Polygon 2 falls in this zone.

        my $Adjust=0.0;
        if ( $Polygon1[1] < 0.0 ) {
	    $Adjust=$Polygon1[1]+180.0;	
	    $Offset1=$Adjust if ($Adjust > $Offset1);
	    $Polygon1[1]=$Polygon1[1]+360.0;
        }
        if ( $Polygon1[3] < 0.0 ) {
	    $Adjust=$Polygon1[3]+180.0;	
	    $Offset1=$Adjust if ($Adjust > $Offset1);
	    $Polygon1[3]=$Polygon1[3]+360.0;
        }
        if ( $Polygon1[5] < 0.0 ) {
	    $Adjust=$Polygon1[5]+180.0;	
	    $Offset1=$Adjust if ($Adjust > $Offset1);
	    $Polygon1[5]=$Polygon1[5]+360.0;
        }
        if ( $Polygon1[7] < 0.0 ) {
	    $Adjust=$Polygon1[7]+180.0;	
	    $Offset1=$Adjust if ($Adjust > $Offset1);
	    $Polygon1[7]=$Polygon1[7]+360.0;
        }
    }

    # Check if Polygon2 crosses the -180/180 Discontinuity ( Polygon indices 1 & 5 > indices 3 7 )

    my $Offset2=0.0;
    if ( $Polygon2[1] > $Polygon2[3] || $Polygon2[1] > $Polygon2[7] || $Polygon2[5] > $Polygon2[3] || $Polygon2[5] > $Polygon2[7] ) {

        # .... Polygon 2 crosses discontinuity ... need to extend the range of the longitude for negative longitudes by adding 360.
        # .... Also keep track of how much extension was required in case a normal western hemisphere Polygon 1 falls in this zone.


        my $Adjust=0.0;
        if ( $Polygon2[1] < 0.0 ) {
	    $Adjust=$Polygon2[1]+180.0;	
	    $Offset2=$Adjust if ($Adjust > $Offset2);
	    $Polygon2[1]=$Polygon2[1]+360.0;
        }
        if ( $Polygon2[3] < 0.0 ) {
	    $Adjust=$Polygon2[3]+180.0;	
	    $Offset2=$Adjust if ($Adjust > $Offset2);
	    $Polygon2[3]=$Polygon2[3]+360.0;
        }
        if ( $Polygon2[5] < 0.0 ) {
	    $Adjust=$Polygon2[5]+180.0;	
	    $Offset2=$Adjust if ($Adjust > $Offset2);
	    $Polygon2[5]=$Polygon2[5]+360.0;
        }
        if ( $Polygon2[7] < 0.0 ) {
	    $Adjust=$Polygon2[7]+180.0;	
	    $Offset2=$Adjust if ($Adjust > $Offset2);
	    $Polygon2[7]=$Polygon2[7]+360.0;
        }
    }

    # If both Polygons needed discontinuity adjustment we can continue with the overlap test
    # If both Polygons needed no discontinuity adjustment we can continue with the overlap test
    # If one Polygone was adjusted we need to determine if the other was in the "adjustment" zone and fix it accordingly

    if ( $Offset1 > 0.0 && $Offset2 == 0.0 ) {

        # ... Need to check  Western side of Polygon2

        if ( 180.0+$Polygon2[1] <= $Offset1 || 180.0+$Polygon2[5] <= $Offset1 ) {

	    # ...... In the zone adjust all four Longitudes of Polygon2...

	    $Polygon2[1]=$Polygon2[1]+360.0;
	    $Polygon2[3]=$Polygon2[3]+360.0;
	    $Polygon2[5]=$Polygon2[5]+360.0;
	    $Polygon2[7]=$Polygon2[7]+360.0;
        }


    } elsif ($Offset1 == 0.0 && $Offset2 > 0.0 ) {

        # ... Need to check  Western side of Polygon2

        if ( 180.0+$Polygon1[1] <= $Offset2 || 180.0+$Polygon1[5] <= $Offset2 ) {

	    # ...... In the zone adjust all four Longitudes of Polygon2...

	    $Polygon1[1]=$Polygon1[1]+360.0;
	    $Polygon1[3]=$Polygon1[3]+360.0;
	    $Polygon1[5]=$Polygon1[5]+360.0;
	    $Polygon1[7]=$Polygon1[7]+360.0;
        }
    }

    # At this point both polygons are adjusted to a common coordinate system ... 
    # Proceeding to check for overlap.

    # Odd number points of Polygon Array are assumed to be Longitude. Build a Longitude only array
    # for both Polygons and switch the last two coordinates to get the same smooth clockwise rotation 
    # used for the Latitude arrays
 
    my @Lon1=($Polygon1[1],$Polygon1[3],$Polygon1[7],$Polygon1[5]);
    my @Lon2=($Polygon2[1],$Polygon2[3],$Polygon2[7],$Polygon2[5]);

    # Find the Max Min Longitudes for Polygon 1.

    my $MaxLon1=-180.0;
    my $MinLon1=180.0;
    for my $i (@Lon1) {
        $MaxLon1 = $i if ($MaxLon1 < $i);
        $MinLon1 = $i if ($MinLon1 > $i);
    }

    # Find the Max Min Longitudes for Polygon 2.

    my $SuperMaxLon=$MaxLon1;
    my $SuperMinLon=$MinLon1;

    my $MaxLon2=-180.0;
    my $MinLon2=180.0;
    for my $i (@Lon2) {
        $MaxLon2 = $i if ($MaxLon2 < $i);
        $MinLon2 = $i if ($MinLon2 > $i);
        $SuperMaxLon = $i if ($SuperMaxLon < $i);
        $SuperMinLon = $i if ($SuperMinLon > $i);
    }


    # No Overlap in Longitude ... return a false and exit
  
    if ( $MaxLon2 < $MinLon1 ) {
        return "No Overlap (Coarse Longitude)";
    } elsif ( $MaxLon1 < $MinLon2 ) {
        return "No Overlap (Coarse Longitude)";
    }

    # At this point we have determined that two bounding Rectangles (in Lat and Lon) might overlap 
    # taking into account the discontinuity at -180/180 degrees Longitude and 6.0 degrees of latitude
    # slop to adjust for possible great circle intersection at northern and southern edges.
    # 
    # At this point we need to project the polygons onto a gnomonic plane to make a finer determination.
    # However the Gnonomic projection is limited to < 180 degrees of angular separation between points.
    # Because the Arctanget goes infinite at the projection Equator. We will use Spherical Trig's Law 
    # of Cosines to determine if the polygons in the problem fit this constraint

    # Check Polygon 1

    my $CoLat1=90.0-$MaxLat1;
    my $CoLat2=90.0-$MinLat1;
    my $DLon=$MaxLon1-$MinLon1;

    my $D1 = cos(deg2rad($CoLat1))*cos(deg2rad($CoLat1))+sin(deg2rad($CoLat1))*sin(deg2rad($CoLat1))*cos(deg2rad($DLon));
    my $D2 = cos(deg2rad($CoLat1))*cos(deg2rad($CoLat2))+sin(deg2rad($CoLat1))*sin(deg2rad($CoLat2))*cos(deg2rad($DLon));
    my $D3 = cos(deg2rad($CoLat1))*cos(deg2rad($CoLat2))+sin(deg2rad($CoLat1))*sin(deg2rad($CoLat2));

    $D1 = rad2deg(acos($D1));
    $D2 = rad2deg(acos($D2));
    $D3 = rad2deg(acos($D3));

    if ( $opt_d ) {
	print "\n    Polygon Angular Extents\n";
	print "        Polygon 1 : $D1 $D2 $D3\n";
    }

    if ( $D1 < -170.0 || $D1 > 170.0 ) {
	return "Overlap (Polygon 1 is too large for fine scale comparison)";
    } elsif ( $D2 < -170.0 || $D2 > 170.0 ) {
	return "Overlap (Polygon 1 is too large for fine scale comparison)";
    } elsif ( $D3 < -170.0 || $D3 > 170.0 ) {
	return "Overlap (Polygon 1 is too large for fine scale comparison)";
    }

    # Check Polygon 2

    $CoLat1=90.0-$MaxLat2;
    $CoLat2=90.0-$MinLat2;
    $DLon=$MaxLon2-$MinLon2;

    $D1 = cos(deg2rad($CoLat1))*cos(deg2rad($CoLat1))+sin(deg2rad($CoLat1))*sin(deg2rad($CoLat1))*cos(deg2rad($DLon));
    $D2 = cos(deg2rad($CoLat1))*cos(deg2rad($CoLat2))+sin(deg2rad($CoLat1))*sin(deg2rad($CoLat2))*cos(deg2rad($DLon));
    $D3 = cos(deg2rad($CoLat1))*cos(deg2rad($CoLat2))+sin(deg2rad($CoLat1))*sin(deg2rad($CoLat2));

    $D1 = rad2deg(acos($D1));
    $D2 = rad2deg(acos($D2));
    $D3 = rad2deg(acos($D3));

    if ( $opt_d ) {
	print "        Polygon 2 : $D1 $D2 $D3\n";
    }

    if ( $D1 < -170.0 || $D1 > 170.0 ) {
	return "Overlap (Polygon 2 is too large for fine scale comparison)";
    } elsif ( $D2 < -170.0 || $D2 > 170.0 ) {
	return "Overlap (Polygon 2 is too large for fine scale comparison)";
    } elsif ( $D3 < -170.0 || $D3 > 170.0 ) {
	return "Overlap (Polygon 2 is too large for fine scale comparison)";
    }

    # Check Both

    $CoLat1=90.0-$SuperMaxLat;
    $CoLat2=90.0-$SuperMinLat;
    $DLon=$SuperMaxLon-$SuperMinLon;

    $D1 = cos(deg2rad($CoLat1))*cos(deg2rad($CoLat1))+sin(deg2rad($CoLat1))*sin(deg2rad($CoLat1))*cos(deg2rad($DLon));
    $D2 = cos(deg2rad($CoLat1))*cos(deg2rad($CoLat2))+sin(deg2rad($CoLat1))*sin(deg2rad($CoLat2))*cos(deg2rad($DLon));
    $D3 = cos(deg2rad($CoLat1))*cos(deg2rad($CoLat2))+sin(deg2rad($CoLat1))*sin(deg2rad($CoLat2));

    $D1 = rad2deg(acos($D1));
    $D2 = rad2deg(acos($D2));
    $D3 = rad2deg(acos($D3));

    if ( $opt_d ) {
	print "        Joint     : $D1 $D2 $D3\n";
    }

    if ( $D1 < -170.0 || $D1 > 170.0 ) {
	return "Overlap (Polygon pair covers too much area for fine determination)";
    } elsif ( $D2 < -170.0 || $D2 > 170.0 ) {
	return "Overlap (Polygon pair covers too much area for fine determination)";
    } elsif ( $D3 < -170.0 || $D3 > 170.0 ) {
	return "Overlap (Polygon pair covers too much area for fine determination)";
    }

    # The First polygon is assumed to be the Search box the User is interested in. We will locate the pole of the   
    # oblique gnomonic projection at the approximate center of this polygon. The center is calculated by averaging the 3-D
    # Vector components of the 4 cornersi and then normalizing to the surface of the sphere. This is not prefect but should 
    # be able to handle search polygons anywhere on the globe .. particularly if the user search box should include the 
    # north or south pole 

    # In order to calculate the oblique Gmononic Projection we need to translate to a coordinate system where the center
    # of polygon 1 is now the North Pole. This is simply done by using the first two euler rotations and the longitude and colatitude
    # of the Center. As we don't care how the plot is oriented about the new pole this means we can assume the third euler rotation is
    # zero. This gives the following relationship between the new coordinate system (Upper Case) and the old (lower case)
    #
    #    X = x*cos(lon)*cos(colat)+y*sin(lon)*cos(colat)-z*sin(colat)
    #    Y = -x*sin(lon)+y*cos(lon)
    #    Z = x*cos(lon)*sin(colat)+y*sin(lon)*sin(colat)+z*cos(colat)
    #
    # where colat and lon are the Colatitude and Longitude of the polygon center. x,y,z are the cartesian coordinates of an arbitary point on
    # the globe with a colatitude and longitude of COLAT and LON and are given by the following equations
    #   
    #    x=sin(COLAT)*cos(LON)
    #    y=sin(COLAT)*sin(LON)
    #    z=cos(COLAT)
    #

    # Calculate the center of the first polygon (Search box) and the Tangent point of the projection plane

    my $z = ( cos(deg2rad(90.0-$Lat1[0]))+cos(deg2rad(90.0-$Lat1[1]))+cos(deg2rad(90.0-$Lat1[2]))+cos(deg2rad(90.0-$Lat1[3])))/4.0;
    my $y = ( sin(deg2rad($Lon1[0]))*sin(deg2rad(90.0-$Lat1[0]))+sin(deg2rad($Lon1[1]))*sin(deg2rad(90.0-$Lat1[1]))+
              sin(deg2rad($Lon1[2]))*sin(deg2rad(90.0-$Lat1[2]))+sin(deg2rad($Lon1[3]))*sin(deg2rad(90.0-$Lat1[3])))/4.0;
    my $x = ( cos(deg2rad($Lon1[0]))*sin(deg2rad(90.0-$Lat1[0]))+cos(deg2rad($Lon1[1]))*sin(deg2rad(90.0-$Lat1[1]))+
              cos(deg2rad($Lon1[2]))*sin(deg2rad(90.0-$Lat1[2]))+cos(deg2rad($Lon1[3]))*sin(deg2rad(90.0-$Lat1[3])))/4.0;

    my $normal = sqrt($x*$x+$y*$y+$z*$z);

    my $Clat = rad2deg(acos($z/$normal));
    my $Clon = rad2deg(atan2($y,$x)); 

    if ( $opt_d ) {
	print "\n    Projection Tangent Point (Center of Polygon 1 aka Search Box)\n";
	printf "        Vector  : %8.3f %8.3f %8.3f\n",$x,$y,$z;
	printf "        Factor  : %8.3f\n",$normal;
	printf "        Lat,Lon : %8.3f, %8.3f\n",90.0-$Clat,$Clon;
    }

    # Calculate the Factors of the rotation Matrix

    my $CT = cos(deg2rad($Clat));
    my $ST = sin(deg2rad($Clat));
    my $CN = cos(deg2rad($Clon));
    my $SN = sin(deg2rad($Clon));
    my $CNCT = $CN*$CT;
    my $CNST = $CN*$ST;
    my $SNCT = $SN*$CT;
    my $SNST = $SN*$ST;

    # Calculate the cartesian coordinates of the new pole for a sanity check
  
    $x = sin(deg2rad($Clat))*cos(deg2rad($Clon));
    $y = sin(deg2rad($Clat))*sin(deg2rad($Clon));
    $z = cos(deg2rad($Clat));

    my $X = $x*$CNCT+$y*$SNCT-$z*$ST;
    my $Y = -$x*$SN+$y*$CN;
    my $Z = $x*$CNST+$y*$SNST+$z*$CT;

    my $Lon=rad2deg(atan2($Y,$X));
    my $Lat=90.0-rad2deg(acos($Z));

    if ( $opt_d ) {
	print  "\n    Rotated Pole 3-D Coordinates\n";
	printf "        Pole      : X,Y,Z = %8.3f %8.3f,%8.3f : Lat,Lon = %8.3f,%8.3f\n",$X,$Y,$Z,$Lat,$Lon;
	print "\n    Rotation Matrix\n";
	printf "        %8.3f   %8.3f   %8.3f\n",$CNCT,$SNCT,-$ST;
	printf "        %8.3f   %8.3f   %8.3f\n",-$SN,$CN,0.0;
	printf "        %8.3f   %8.3f   %8.3f\n",$CNST,$SNST,$CT;
	print "\n    Rotated Polygon 3-D Coordinates\n";

    }

    # Rotate Polygon 1 corners to new coordinate system

    for my $i ( 0,1,2,3 ) {

        $x = sin(deg2rad(90.0-$Lat1[$i]))*cos(deg2rad($Lon1[$i]));
        $y = sin(deg2rad(90.0-$Lat1[$i]))*sin(deg2rad($Lon1[$i]));
        $z = cos(deg2rad(90.0-$Lat1[$i]));

        $X = $x*$CNCT+$y*$SNCT-$z*$ST;
    	$Y = -$x*$SN+$y*$CN;
    	$Z = $x*$CNST+$y*$SNST+$z*$CT;

        $Lon=rad2deg(atan2($Y,$X));
        $Lat=90.0-rad2deg(acos($Z));

	if ( $opt_d ) {
	    printf "        Polygon 1 : X,Y,Z = %8.3f %8.3f,%8.3f : Lat,Lon = %8.3f,%8.3f\n",$X,$Y,$Z,$Lat,$Lon;
	}
	$Lon1[$i]=$Lon;
	$Lat1[$i]=$Lat;
    }

    if ( $opt_d ) {
	print " \n";
    }

    # Rotate Polygon 2 corners to new coordinate system

    for my $i ( 0,1,2,3) {

        $x = sin(deg2rad(90.0-$Lat2[$i]))*cos(deg2rad($Lon2[$i]));
        $y = sin(deg2rad(90.0-$Lat2[$i]))*sin(deg2rad($Lon2[$i]));
        $z = cos(deg2rad(90.0-$Lat2[$i]));

        $X = $x*$CNCT+$y*$SNCT-$z*$ST;
    	$Y = -$x*$SN+$y*$CN;
    	$Z = $x*$CNST+$y*$SNST+$z*$CT;

        $Lon=rad2deg(atan2($Y,$X));
        $Lat=90.0-rad2deg(acos($Z));

	if ( $opt_d ) {
	    printf "        Polygon 2 : X,Y,Z = %8.3f %8.3f,%8.3f : Lat,Lon = %8.3f,%8.3f\n",$X,$Y,$Z,$Lat,$Lon;
	}
	$Lon2[$i]=$Lon;
	$Lat2[$i]=$Lat;
    }


    # Calculate the Gnonomic Coordinates of the Polygons... This preserves the point switch we did in the original LatN and LonN arrays so 
    # that the polygons are described in a clockwise progression of points (note we swap the first and lat points in each polygon in the XC and YC
    # arrays because in later steps we need to take differences of the points... this maintains the clockwise definition of a polygon basically and
    # simplifies the orthogonal line check indices

    my @Q1=(100.0*tan(deg2rad(90.0-$Lat1[0])),100.0*tan(deg2rad(90.0-$Lat1[1])),100.0*tan(deg2rad(90.0-$Lat1[2])),100.0*tan(deg2rad(90.0-$Lat1[3])));
    my @Q2=(100.0*tan(deg2rad(90.0-$Lat2[0])),100.0*tan(deg2rad(90.0-$Lat2[1])),100.0*tan(deg2rad(90.0-$Lat2[2])),100.0*tan(deg2rad(90.0-$Lat2[3])));


    my @XC=($Q1[1]*cos(deg2rad($Lon1[1])),$Q1[2]*cos(deg2rad($Lon1[2])),$Q1[3]*cos(deg2rad($Lon1[3])),$Q1[0]*cos(deg2rad($Lon1[0])),
            $Q2[1]*cos(deg2rad($Lon2[1])),$Q2[2]*cos(deg2rad($Lon2[2])),$Q2[3]*cos(deg2rad($Lon2[3])),$Q2[0]*cos(deg2rad($Lon2[0])));

    my @YC=($Q1[1]*sin(deg2rad($Lon1[1])),$Q1[2]*sin(deg2rad($Lon1[2])),$Q1[3]*sin(deg2rad($Lon1[3])),$Q1[0]*sin(deg2rad($Lon1[0])),
            $Q2[1]*sin(deg2rad($Lon2[1])),$Q2[2]*sin(deg2rad($Lon2[2])),$Q2[3]*sin(deg2rad($Lon2[3])),$Q2[0]*sin(deg2rad($Lon2[0])));

    # With the points safely projected to a 2-D Plane we can safely average the X and Y coordinates to get the geometric center of each polygon
    # and determine the radial spacing of the centers. We next find the biggest circle that contains the the given polygon. The sum of the
    # the radaii of the two polygons better equal or exceed the distance between the geometric centers. If not ... the Polygons dont intersect.

    my $SumX1=($XC[0]+$XC[1]+$XC[2]+$XC[3])/4.0;
    my $SumY1=($YC[0]+$YC[1]+$YC[2]+$YC[3])/4.0;
    my $SumX2=($XC[4]+$XC[5]+$XC[6]+$XC[7])/4.0;
    my $SumY2=($YC[4]+$YC[5]+$YC[6]+$YC[7])/4.0;
    my $Radius=sqrt(($SumX1-$SumX2)*($SumX1-$SumX2)+($SumY1-$SumY2)*($SumY1-$SumY2));

    my @Test1=(sqrt(($XC[0]-$SumX1)*($XC[0]-$SumX1)+($YC[0]-$SumY1)*($YC[0]-$SumY1)),
               sqrt(($XC[1]-$SumX1)*($XC[1]-$SumX1)+($YC[1]-$SumY1)*($YC[1]-$SumY1)),
               sqrt(($XC[2]-$SumX1)*($XC[2]-$SumX1)+($YC[2]-$SumY1)*($YC[2]-$SumY1)),
               sqrt(($XC[3]-$SumX1)*($XC[3]-$SumX1)+($YC[3]-$SumY1)*($YC[3]-$SumY1)));

    my $MaxTest1=0;
    for my $i (@Test1) {
        $MaxTest1 = $i if ($MaxTest1 < $i);
    }

    my @Test2=(sqrt(($XC[4]-$SumX2)*($XC[4]-$SumX2)+($YC[4]-$SumY2)*($YC[4]-$SumY2)),
               sqrt(($XC[5]-$SumX2)*($XC[5]-$SumX2)+($YC[5]-$SumY2)*($YC[5]-$SumY2)),
               sqrt(($XC[6]-$SumX2)*($XC[6]-$SumX2)+($YC[6]-$SumY2)*($YC[6]-$SumY2)),
               sqrt(($XC[7]-$SumX2)*($XC[7]-$SumX2)+($YC[7]-$SumY2)*($YC[7]-$SumY2)));
    
    my $MaxTest2=0;
    for my $i (@Test2) {
        $MaxTest2 = $i if ($MaxTest2 < $i);
    }

    if ( $opt_d ) {
	print "\n    Polygon Radius Screening\n";
	printf "        Center Polygon 1 : %8.3f, %8.3f\n",$SumX1,$SumY1;
	printf "        Center Polygon 2 : %8.3f, %8.3f\n",$SumX2,$SumY2;
	printf "        Square Distance  : %8.3f\n",$Radius;
	printf "        Test Radii 1     : %8.3f, %8.3f, %8.3f %8.3f\n",$Test1[0],$Test1[1],$Test1[2],$Test1[3];
	printf "        Test Radii 2     : %8.3f, %8.3f, %8.3f %8.3f\n",$Test2[0],$Test2[1],$Test2[2],$Test2[3];
    }
	
    if ($MaxTest2+$MaxTest1 < $Radius ) {
        return "No Overlap (Radius Test)";
    }

    # The final test is to take the line defined by each of the edges of the polygons and calculate an  
    # orthogonal line to the edge. Next we project the 8 corner points onto this line. If the projected 
    # corner points don't overlap on the 1-D line this means a line can be drawn between the two polygons
    # that crosses neither and therefore the polygons don't overlap. All 8 edges need to be checked to 
    # determine if the Polygons overlap ... a single case of non-overlap allows termination of the check
    # with a non-overlap conclusion.

    my @deltaY = (($YC[0]-$YC[3]),
		  ($YC[1]-$YC[0]),
		  ($YC[2]-$YC[1]),
		  ($YC[3]-$YC[2]),
                  ($YC[4]-$YC[7]),
		  ($YC[5]-$YC[4]),
		  ($YC[6]-$YC[5]),
		  ($YC[7]-$YC[6]));

    my @deltaX = (($XC[0]-$XC[3]),
		  ($XC[1]-$XC[0]),
		  ($XC[2]-$XC[1]),
		  ($XC[3]-$XC[2]),
                  ($XC[4]-$XC[7]),
		  ($XC[5]-$XC[4]),
		  ($XC[6]-$XC[5]),
		  ($XC[7]-$XC[6]));

    my @B = (0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0);
    my @Theta = (0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0);

    for my $i ( 0,1,2,3,4,5,6,7 ) {
	if ( abs($deltaX[$i]) > 0.0000001 ) {
            $B[$i]=($YC[$i]-$XC[$i]*$deltaY[$i]/$deltaX[$i]);
	} else {
	    $deltaX[$i]=0.0;
            $B[$i]=$XC[$i];
	}
        $Theta[$i] = rad2deg(atan2($deltaX[$i],$deltaY[$i]));
    }

    # These are the Edge data used in the determination. Basically the orthogonal determined by a coordinate 
    # translation to the y intercept (vertical lines are reduced to the y axis) and then a clockwise rotation of 90
    # degrees with the slope of the line (delta Y/delta X) defining the rotation matrix with regard to the X axis
    #
    #                              cos(90-slope) -sin(90-slope)
    #                              sin(90-slope)  cos(90-slope)

  
    if ( $opt_d ) {
	print "\n    Polygon 1 Gnomonic Coordinates\n";
	printf "        %9.3f,%9.3f,%9.3f,%9.3f,%9.3f,%9.3f\n",$XC[0],$YC[0],$deltaX[0],$deltaY[0],$B[0],$Theta[0];
	printf "        %9.3f,%9.3f,%9.3f,%9.3f,%9.3f,%9.3f\n",$XC[1],$YC[1],$deltaX[1],$deltaY[1],$B[1],$Theta[1];
	printf "        %9.3f,%9.3f,%9.3f,%9.3f,%9.3f,%9.3f\n",$XC[2],$YC[2],$deltaX[2],$deltaY[2],$B[2],$Theta[2];
	printf "        %9.3f,%9.3f,%9.3f,%9.3f,%9.3f,%9.3f\n",$XC[3],$YC[3],$deltaX[3],$deltaY[3],$B[3],$Theta[3];
	print "\n    Polygon 2 Gnomonic Coordinates\n";
	printf "        %9.3f,%9.3f,%9.3f,%9.3f,%9.3f,%9.3f\n",$XC[4],$YC[4],$deltaX[4],$deltaY[4],$B[4],$Theta[4];
	printf "        %9.3f,%9.3f,%9.3f,%9.3f,%9.3f,%9.3f\n",$XC[5],$YC[5],$deltaX[5],$deltaY[5],$B[5],$Theta[5];
	printf "        %9.3f,%9.3f,%9.3f,%9.3f,%9.3f,%9.3f\n",$XC[6],$YC[6],$deltaX[6],$deltaY[6],$B[6],$Theta[6];
	printf "        %9.3f,%9.3f,%9.3f,%9.3f,%9.3f,%9.3f\n",$XC[7],$YC[7],$deltaX[7],$deltaY[7],$B[7],$Theta[7];
    }

    # Assume the polygons Overlap until proven otherwise

	    
    my $overlap="Overlap";

    # Testing each of the Edges

    my $TestLo1=0;
    my $TestHi1=0;
    my $TestLo2=0;
    my $TestHi2=0;

    if ($opt_d) {
	print "\n    Edge Tests\n";
    }

    # For each of the eight edges
 
    for my $i ( 0,1,2,3,4,5,6,7 ) {

	# For each of the corner points in the two polygons

	for my $j ( 0,1,2,3,4,5,6,7 ) {

	    if ( $deltaX[$i] == 0.0 ) {
	        $X=$XC[$j]-$B[$i];
	    } else {
	        $X=$XC[$j]*cos(deg2rad($Theta[$i]))-($YC[$j]-$B[$i])*sin(deg2rad($Theta[$i]));
	    }
	
	    if ( $j == 0 ) {
	        $TestLo1 = $X;
	        $TestHi1 = $X;
	    } elsif ( $j < 4 ) {
	        $TestLo1 = $X if ( $TestLo1 > $X );
	        $TestHi1 = $X if ( $TestHi1 < $X );
	    } elsif ( $j == 4 ) {
	       $TestLo2 = $X;
	       $TestHi2 = $X;
	    } else {
	        $TestLo2 = $X if ( $TestLo2 > $X );
	        $TestHi2 = $X if ( $TestHi2 < $X );
	    }
	}

	# See if there is overlap (for debug we will do all cases otherwise it is sudden death with no overlap for operational case

	if ( $TestHi2 < $TestLo1 || $TestHi1 < $TestLo2 ) {
	    if ( $opt_d ) {
		printf "        Edge %1d : No Overlap : %10.2f %10.2f ..... %10.2f %10.2f\n",$i,$TestLo1,$TestHi1,$TestLo2,$TestHi2;
		$overlap="No Overlap (Edge $i)";
	    } else {
		return "No Overlap (Edge $i)";
	    }
	} else {
	    if ( $opt_d ) {
		printf "        Edge %1d :    Overlap : %10.2f %10.2f ..... %10.2f %10.2f\n",$i,$TestLo1,$TestHi1,$TestLo2,$TestHi2;
	    }
	}
    }

    return $overlap;
};

################################################################################

=head2 searchGranule

Description:
    Returns the search results for granules in ECHO
    
Input:
    Accepts granule attributes.
    
Output:
    Returns search result as a hash or undefined. Keys of the hash are ECHO
    granule URs and the values are metadata.
    
Author:
    M. Hegde
    
=cut

sub searchGranule
{
    my ( $self, %arg ) = @_;
    unless ( $self->loggedIn() ) {
        print STDERR "searchGranule(): not logged in!";
        return undef;
    }
    my $startDate = ''; 
    my $stopDate = ''; 
    my $echoUri = $self->getEchoUri();
    my $proxyServer = $self->getProxyServer();
    my $xmlParser = XML::LibXML->new();
    $xmlParser->keep_blanks(0);
    my $query = qq(
          <query>
        <for value="granules"/>
        <dataCenterId>DATA_CENTER_ID</dataCenterId>
        <where>
            <granuleCondition>
                <collectionShortName><value>'$arg{DATASET}'</value></collectionShortName>
            </granuleCondition>
            <granuleCondition>
                <collectionVersionId><value>'$arg{VERSION}'</value></collectionVersionId>
            </granuleCondition>
        </where>
      </query> );
    my $dataCenterId = defined $arg{DATA_CENTER_ID} ? qq(<value>$arg{DATA_CENTER_ID}</value>) : qq(<all />);
    $query =~ s/DATA_CENTER_ID/$dataCenterId/;
    my $aqlQuery = $xmlParser->parse_string( $query );
    my ( $whereClause ) = $aqlQuery->findnodes( '/query/where' );
    my $temporal;
    my $searchBox = [];
    foreach my $key ( keys %arg ) {
        next if ( $key eq 'DATASET' || $key eq 'VERSION' );
        my $condition = XML::LibXML::Element->new( 'granuleCondition' );
        if ( $key eq 'BEGIN_DATE' ) {
            my $startDate = getDateElement( $arg{BEGIN_DATE} );
            unless ( defined $temporal ) {
                $temporal = $condition->appendChild(
                    XML::LibXML::Element->new( 'temporal' ) );
            }
            $temporal->appendWellBalancedChunk(
                qq(<startDate>$startDate</startDate>) );
        } elsif ( $key eq 'END_DATE' ) {
            my $stopDate = getDateElement( $arg{END_DATE} );
            unless ( defined $temporal ) {
                $temporal = $condition->appendChild(
                    XML::LibXML::Element->new( 'temporal' ) );
            }
            $temporal->appendWellBalancedChunk(
                qq(<stopDate>$stopDate</stopDate>) );
        } elsif ( $key eq 'BOUNDING_BOX' ) {
            my @box = @{$arg{BOUNDING_BOX}};
            if ( @box >= 4 ) {
                my $spatial = XML::LibXML::Element->new( 'spatial' );
                my $polygon = $spatial->appendChild(
                    XML::LibXML::Element->new( 'IIMSPolygon' ) );
                my $ring = $polygon->appendChild(
                    XML::LibXML::Element->new( 'IIMSLRing' ) );
                if ( @box == 4 ) {
                    # Case of bounding box corners specifie
                    $searchBox = [ $box[1], $box[0], $box[1], $box[2], $box[3],
                         $box[0], $box[3], $box[2] ];
                    my @newBox = (
                        $box[0], $box[1],
                        $box[0], $box[3],
                        $box[2], $box[3],
                        $box[2], $box[1],
                        $box[0], $box[1]
                        );
                    @box = @newBox;
                }
                #for ( my $i=0 ; $i<@box ; $i+=2 ) {
                #    my $point = XML::LibXML::Element->new( 'IIMSPoint' );
                #    $point->setAttribute( 'long', $box[$i] );
                #    $point->setAttribute( 'lat', $box[$i+1] );
                #    $ring->appendChild( $point );
                #}
                #$condition->appendChild( $spatial ) if ( @box );
            }
        }
        $whereClause->appendChild( $condition ) if ( $condition->childNodes() );
    }
    my $queryString = $aqlQuery->documentElement()->toString(1);
    my $query = qq(
<s0:query xmlns:s0=\"$echoUri\"><![CDATA[<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE query SYSTEM "$proxyServer/echo/dtd/IIMSAQLQueryLanguage.dtd">
    $queryString
    ]]>
</s0:query>
);
    #my $a = $query;
    #$a =~ s/\s+/ /g;
    #print "$a\n";
    my $queryElement = SOAP::Data->type( xml => $query );
    my $queryResultTypeElement = $self->soapEchoData( NAME => 'queryResultType',
        TYPE => '', VALUE => 'HITS' );    
    my $iteratorSizeElement = $self->soapEchoData( NAME => 'iteratorSize',
        TYPE => 'int', VALUE => 0 );
    my $cursorElement = $self->soapEchoData( NAME => 'cursor',
        TYPE => 'int', VALUE => 0 );
    my $maxResultElement = $self->soapEchoData( NAME => 'maxResults',
        TYPE => 'int', VALUE => 0 );
    my $metadataAttributeElement = $self->soapEchoData(
        NAME => 'metadataAttributes', TYPE => '', VALUE => '' );
    my $som = SOAP::Lite->uri( $self->getEchoUri() )
        ->proxy( $self->getProxyUri() . 'CatalogServicePortImpl',
            timeout => '3600' )
        ->ExecuteQuery( $self->getTokenElement(), $queryElement,
            $queryResultTypeElement, $iteratorSizeElement, $cursorElement,
            $maxResultElement, $metadataAttributeElement);

    if ( $som->fault ) {
        $self->{_error} = "Error executing catalog query: " 
            . $som->fault->{faultstring};
        return undef;
    }
    
    my $resultSetGuid = $som->valueof( '//ResultSetGuid' );
    my $resultSetGuidElement = $self->soapEchoData( NAME => 'resultSetGuid',
                                                    TYPE  => 'string',
                                                    VALUE => $resultSetGuid );
    my $hits = $som->valueof( '//Hits/Size' );

    my $cursor = 1;
    my $searchResult = {};
CURSOR: while ( $cursor <= $hits ) {
        $cursorElement = $self->soapEchoData( NAME => 'cursor',
            TYPE => 'int', VALUE => $cursor );
        my $som = SOAP::Lite->uri( $self->getEchoUri() )
            ->proxy( $self->getProxyUri() . 'CatalogServicePortImpl',
                timeout => '300' )
            ->GetQueryResults( $self->getTokenElement(), $resultSetGuidElement,
                $metadataAttributeElement, $iteratorSizeElement, $cursorElement );
        if ( $som->fault ) {
            $self->{_error} = "Error executing catalog query: " 
                . $som->fault->{faultstring};
            last CURSOR;
        }
        my $results = $som->valueof( '//ReturnData' );
        my $dom = $xmlParser->parse_string( $results );
        my $doc = $dom->documentElement();
        GRANULE_LOOP: foreach my $node ( $doc->findnodes( '//GranuleURMetaData' ) ) {
            my $granuleUr = $node->findvalue( 'GranuleUR' );
            my $granuleSize = $node->findvalue( 'GranuleSize' );
            my $productionTime = $node->findvalue( 'DataGranule/ProductionDateTime' );
            my ( $beginDate, $beginTime, $endDate, $endTime ) =
                (
                    $node->findvalue( 'RangeDateTime/RangeBeginningDate' ),
                    $node->findvalue( 'RangeDateTime/RangeBeginningTime' ),
                    $node->findvalue( 'RangeDateTime/RangeEndingDate' ),
                    $node->findvalue( 'RangeDateTime/RangeEndingTime' ) 
                );
            ( $beginDate, ) = split( /\s+/, $beginDate );
            ( $endDate, ) = split( /\s+/, $endDate );
            
            if ( @$searchBox ) {
                my $box = $getBoundary->( $node );
                $box = $rearrangeBoundary->( $box );
                my $overlapMsg = $doesOverlap->( $box, $searchBox );
		if ( $self->onDebug() ) {
                    print $overlapMsg, "\n";
                    print join( ",", @$box ), "\n";
		}
                next GRANULE_LOOP if ( $overlapMsg =~ /No/ );
            }

            my @urlList = ();
            foreach my $urlNode ( $node->findnodes( 'OnlineAccessURLs/OnlineAccessURL/URL' ) ) {
                push( @urlList, $urlNode->to_literal );
            }
            
            # Try to find the granule size unless found in metadata
            unless ( $granuleSize ) {
                my $httpAgent = LWP::UserAgent->new();
                foreach my $url ( @urlList ) {
                    my $uri = URI->new( $url );
                    if ( $uri->scheme() eq 'ftp' ) {
                        my $ftp = Net::FTP->new( $uri->host() );
                        $ftp->login();
                        $ftp->binary();
                        $granuleSize += $ftp->size( $uri->path() );
                        $ftp->quit(); 
                    } else {
                        my $response = $httpAgent->head( $url );
                        if ( $response->is_success ) {
                            $granuleSize += $response->header( 'content-length' );
                        }
                    }
                }
            }
            $searchResult->{$granuleUr}{size} = $granuleSize;
            $searchResult->{$granuleUr}{begin} = $beginDate . ' ' . $beginTime;
            $searchResult->{$granuleUr}{end} = $endDate . ' ' . $endTime;
            $searchResult->{$granuleUr}{productiontime} = $productionTime;
            $searchResult->{$granuleUr}{url} = [ @urlList ];
        }
        $cursor++;
    }
    return $searchResult;
}

################################################################################

=head2 login

Description:
    Logs in to ECHO.
    
Input:
    Accepts ECHO username and password.
    
Output:
    1/0 => Login successful/failure.
    
Author:
    M. Hegde
    
=cut

sub login
{
    my ( $self, $user, $pass ) = @_;
    
    my $hostName = Sys::Hostname::hostname();
    my $packedIpAddress = (gethostbyname($hostName))[4];
    my $ipAddress = join('.', unpack('C4', $packedIpAddress));
    my $userElement = $self->soapEchoData( NAME => 'username',
        TYPE => 'string', VALUE => $self->getUser() );
    my $passElement = $self->soapEchoData( NAME => 'password',
        TYPE => 'string', VALUE => $self->getPassword() );
    my $actAsUserNameElement = $self->soapEchoData( NAME => 'actAsUserName',
        TYPE => 'string', VALUE => undef );
    my $behalfOfProviderElement = $self->soapEchoData( 
        NAME => 'behalfOfProvider', TYPE => 'string', VALUE => undef );    
    my $clientIdElement = $self->soapTypesData( NAME => 'ClientId',
        TYPE => 'string', VALUE => 'GESDISC' );
    my $userIpAddress = $self->soapTypesData( NAME => 'UserIpAddress',
        TYPE => 'string', VALUE => $ipAddress );
        
    #  The string identifier of the ECHO client used to make this request
    my $clientInfoElement = $self->soapEchoData( NAME => 'clientInfo',
        VALUE => \SOAP::Data->value( $clientIdElement, $userIpAddress ) );
    my $som;
    my $som = eval { SOAP::Lite->uri( $self->getEchoUri() )
        ->proxy( $self->getProxyUri() . 'AuthenticationServicePortImpl',
            timeout => '300' )
        ->Login( $userElement, $passElement, $clientInfoElement,
            $actAsUserNameElement, $behalfOfProviderElement );
    };
    if ( $@ ) {
        $self->{_error} = "Failed to login: ECHO could be down";
    } elsif ( $som->fault ) {
        $self->{_error} = "Failed to login: " . $som->fault->{faultstring};
    } else {
        my $token = $som->valueof( '//result' );
        my $tokenElement = $self->soapEchoData( NAME => 'token',
            TYPE => 'string', VALUE => $token );
        $self->{token} = $tokenElement;
    }
    $self->{_login} = $self->onError() ? 0 : 1;
    return $self->{_login};
}

################################################################################

=head2 logout

Description:
    Logs out of ECHO session.
    
Input:
    None.
    
Output:
    None.
    
Author:
    M. Hegde
    
=cut

sub logout
{
    my ( $self ) = @_;
    if ( $self->loggedIn() ) {
        my $serviceName = 'AuthenticationServicePortImpl';
        my $response = SOAP::Lite->uri( $self->getEchoUri() )
            ->proxy( $self->getProxyUri() . $serviceName, timeout => '300' )
            ->outputxml( 1 )
            ->readable(1)
            ->Logout( $self->getTokenElement() );
        $self->{_login} = 0;
        print "Logout response: $response\n" if $self->onDebug();
    }
}

sub AUTOLOAD
{
    my ( $self, @arg ) = @_;
    if ( $AUTOLOAD =~ /.*::onError/ ) {
        return ( $self->getErrorMessage() eq '' ? 0 : 1 );
    } elsif ( $AUTOLOAD =~ /.*::getErrorMessage/ ) {
        return $self->{_error};
    } elsif ( $AUTOLOAD =~ /.*::getEchoUri/ ) {
        return $self->{uri}{echo} . 'echo/v10';
    } elsif ( $AUTOLOAD =~ /.*::getProxyUri/ ) {
        return $self->{uri}{proxy} . 'echo-v10/';
    } elsif ( $AUTOLOAD =~ /.*::getTypesUri/ ) {
        return $self->{uri}{echo} . 'echo/v10/types';
    } elsif ( $AUTOLOAD =~ /.*::getProxyServer/ ) {
        return $self->{uri}{proxy};
    } elsif ( $AUTOLOAD =~ /.*::getUser/ ) {
        return $self->{user};
    } elsif ( $AUTOLOAD =~ /.*::getPassword/ ) {
        return $self->{pass};
    } elsif ( $AUTOLOAD =~ /.*::getTokenElement/ ) {
        return $self->{token};
    } elsif ( $AUTOLOAD =~ /.*::onDebug/ ) {
        return $self->{debug};
    } elsif ( $AUTOLOAD =~ /.*::soapEchoData/ ) {
        my %arg = @arg;
        return SOAP::Data->uri( $self->getEchoUri() )
            ->name( $arg{NAME} )->type( $arg{TYPE} )->value( $arg{VALUE} );
    } elsif ( $AUTOLOAD =~ /.*::soapTypesData/ ) {
        my %arg = @arg;
        my $data = SOAP::Data->new();
        $data->uri( $self->getTypesUri() );
        $data->name( $arg{NAME} ) if defined $arg{NAME};
        $data->type( $arg{TYPE} ) if defined $arg{TYPE};
        $data->value( $arg{VALUE} ) if defined $arg{VALUE};
        return $data;
    } elsif ( $AUTOLOAD =~ /.*::loggedIn/ ) {
        return $self->{_login};
    } elsif ( $AUTOLOAD =~ /.*::DESTROY/ ) {
        $self->logout() if $self->loggedIn();
    } else {
        print STDERR "Method $AUTOLOAD not supported\n";
    }
}
1
