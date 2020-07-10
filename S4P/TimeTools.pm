=head1 NAME

TimeTools.pm - of Perl object for time and date manipulation tools

=head1 SYNOPSIS

use S4P::TimeTools;

$new_CCSDS_str = S4P::TimeTools::CCSDSa_DateAdd($old_CCSDS_str, $seconds);

$result =S4P::TimeTools::CCSDSa_DateCompare($CCSDS_str1, $CCSDS_str2);

($year, $month, $day, $hour, $min, $sec, $error) = 
    S4P::TimeTools::CCSDSa_DateParse($CCSDS_str);

$new_CCSDS_str = S4P::TimeTools::CCSDSa_DateFloor($old_CCSDS_str, $interval, $mult);

$new_CCSDS_str = S4P::TimeTools::CCSDSa_DateRound($old_CCSDS_str, $seconds);

$CCSDS_str = S4P::TimeTools::CCSDSa_DateUnparse($year, $month, $day, $hour, $min, $sec);

$CCSDS_str = S4P::TimeTools::CCSDSa_Now;

$CCSDS_str = S4P::TimeTools::timestamp2CCSDSa($timestamp);

$CCSDS_str = S4P::TimeTools::sybase2CCSDSa($string);

$timestamp = S4P::TimeTools::CCSDSa2timestamp($CCSDS_str);

$seconds = S4P::TimeTools::CCSDSa_Diff($CCSDS_str1, $CCSDS_str2);

($year, $day_of_year, $hour, $min, $sec) = 
   S4P::TimeTools::YYYYDDD_DateAdd($year, $day_of_year, 
       $hour, $min, $sec, $increment);

$yyyydddhhmmss = S4P::TimeTools::CCSDSa2yyyydddhhmmss($CCSDS_str);

$CCSDS_str = S4P::TimeTools::yyyydddhhmmss2CCSDSa($yyyydddhhmmss);

@DataTimePairs = S4P::TimeTools::get_data_times($Coverage, 
    $ProcessStartTime, ProcessingPeriod, $Currency, $Boundary);

$CCSDS_str = S4P::TimeTools::getNearestTimeBoundary($CCSDS_str, $Boundary, 
    $Coverage, $Periods);

$Pattern = S4P::TimeTools::get_filename_pattern($data_start_time, $template);

$res = S4P::TimeTools::is_leapyear($year);

$doy = S4P::TimeTools::day_of_year($year, $month, $day);

($newyear, $newmonth, $newday) = 
    S4P::TimeTools::add_delta_days($year, $month, $day, $delta);

($newyear, $newmonth, $newday) = S4P::TimeTools::doy_to_ymd($doy, $year);

$days = S4P::TimeTools::days_in_year($year);

$dow = S4P::TimeTools::day_of_week($year, $month, $day);

($new_year, $new_month, $new_day, $new_hour, $new_min, $new_sec) =
    S4P::TimeTools::add_delta_dhms($year, $month, $day, 
       $hour, $min, $sec,$dd, $dh, $dm, $ds);

($days, $hours, $mins, $secs) = S4P::TimeTools::seconds_to_dhms($seconds);

($days, $hours, $mins, $secs) = 
   S4P::TimeTools::delta_dhms($yr1, $mo1, $day1, $hh1, $mm1, $ss1,
                              $yr2, $mo2, $day2, $hh2, $mm2, $ss2);

$year2 = S4P::TimeTools::CCSDStoy($CCSDS_str);

$year4 = S4P::TimeTools::CCSDStoY($CCSDS_str);

$month = S4P::TimeTools::CCSDStom($CCSDS_str);

$day = S4P::TimeTools::CCSDStod($CCSDS_str);

$hour = S4P::TimeTools::CCSDStoH($CCSDS_str);

$minute = S4P::TimeTools::CCSDStoM($CCSDS_str);

$second = S4P::TimeTools::CCSDStoS($CCSDS_str);

$doy = S4P::TimeTools::CCSDStoj($CCSDS_str);

$short_month  = S4P::TimeTools::CCSDStob($CCSDS_str);

$long_month  = S4P::TimeTools::CCSDStoB($CCSDS_str);

$dow  = S4P::TimeTools::CCSDStou($CCSDS_str);

@times = S4P::TimeTools::format_CCSDS_to_compare(@times);

=head1 DESCRIPTION

This module contains tools for manipulating date and time strings. Currently,
it works only with the CCSDS ASCII time format A strings which have the form:
YYYY-mm-ddThh:mm:ssZ (e.g. 2000-06-28T12:18:59Z).

=over 4

=item CCSDSa_DateAdd

$new_CCSDS_str = S4P::TimeTools::CCSDSa_DateAdd($old_CCSDS_str, $seconds);

This adds $seconds to $old_CCSDS_str and returns $new_CCSDS_str. To subtract,
use negative seconds. If there is an error, the string "ERROR" is returned
instead.

=item CCSDSa_DateCompare

$result = S4P::TimeTools::CCSDSa_DateCompare($CCSDS_str1, $CCSDS_str2);

This compares two date strings and returns -1 if $CCSDS_str1 is LATER than
$CCSDS_str2, 0 if they are equal, and 1 if $CCSDS_str1 is EARLIER than
$CCSDS_str2. Times are rounded to the nearest second.

=item CCSDSa_DateParse

($year, $month, $day, $hour, $min, $sec, $error) = S4P::TimeTools::CCSDSa_DateParse($CCSDS_str);

$ok = S4P::TimeTools::CCSDSa_DateParse($CCSDS_str);

In array context, this parses a date string into year, month, day, hour, 
minute, and second values. 
If the parsing is successful, $error will be set to zero. Otherwise,
$error will be set to one and all other values to zero.

In scalar context, it returns 1 if it parses and zero if there is an error.
=item CCSDSa_DateFloor

$new_CCSDS_str = S4P::TimeTools::CCSDSa_DateFloor($old_CCSDS_str, $interval, $mult);

This returns a date string where the time has been reduced (to an earlier 
time) to the boundary indicated by $interval times $mult. Valids for
$interval are "year", "month", "week", "day", "hour", "min", and "sec". 
For "week", the beginning of the week is Sunday (unlike in ECS where the
beginning of the week is Monday). For "sec", the function really does nothing,
only returning what was input (a long time ago, fractional seconds were thought
to be needed and supported). If an error occurs, the string returned 
is "ERROR".

=item CCSDSa_DateFloorB

$new_CCSDS_str = S4P::TimeTools::CCSDSa_DateFloorB($old_CCSDS_str, $seconds);

This works differently from CCSDSa_DateFloor in that it reduces the time
down to one that is a multiple of $seconds.  The difference can be
illustrated in the following examples:

 S4P::TimeTools::CCSDSa_DateFloor("2000-06-09T10:12:03Z", "hour", 2)

produces "2000-06-09T09:00:00Z".

 S4P::TimeTools::CCSDSa_DateFloorB("2000-06-09T10:12:03Z", 7200)

produces "2000-06-09T10:00:00Z".

=item CCSDSa_DateRound

$new_CCSDS_str = S4P::TimeTools::CCSDSa_DateRound($old_CCSDS_str, $seconds);

This returns a date string that is rounded to the nearest increment in seconds.
For example, if $seconds is 3600, it is rounded to the nearest hour.
If $seconds is 7200, it is rounded to the nearest even hour.

=item CCSDSa_DateUnparse

$CCSDS_str = S4P::TimeTools::CCSDSa_DateUnparse($year, $month, $day, $hour, $min, $sec);

This combines the year, month, day, hour, minute, and second fields into
a CCSDS string of the format YYYY-MM-DDThh:mm:ssZ. If an error occurs,
the string returned is "ERROR".

=item CCSDSa_DateBins

@bins = S4P::TimeTools::CCSDSa_DateBins($start, $stop, $increment)

Returns an array of CCSDSa date/times between $start and $stop spaced
at $increment seconds apart.  The input start and stop are in CCSDSa format.
If stop time falls at an increment boundary, it is not included.

=item CCSDSa_Now

$CCSDS_str = S4P::TimeTools::CCSDSa_Now;

Returns the current local time in a CCSDSa format.

=item timestamp2CCSDSa

Converts S4P-standard timestamp format (YYYY-MM-DD HH:MM:SS) to CCSDSa
(YYYY-MM-DDTHH:MM:SSZ).  If already in that format, it will just return the
input string.

=item CCSDSa2timestamp

The reverse of C<timestamp2CCSDSa>

=item CCSDSa_Diff

Returns the difference in seconds between two CCSDS time strings. The 
returned value is positive if $CCSDS_str1 is earlier than $CCSDS_str2;
it is negative if $CCSDS_str1 is later than $CCSDS_str2. If there is an
error, an undef is returned.

=item YYYYDDD_DateAdd

Similar to CCSDSa_DateAdd, but adds a number of seconds to a date expressed
as a list of ($year, $day_of_year, $hour, $min, $sec).

=item CCSDSa2yyyydddhhmmss

Returns a string of the form yyyydddhhmmss given a CCSDS input.  Useful for
job_ids in S4P work orders.

=item yyyydddhhmmss2CCSDSa

The reverse of C<CCSDSa2yyyydddhhmmss>

=item is_leapyear

Given a full specified year (i.e. where nothing is implied), this function
determines whether or not the year is a leapyear. If it is a leap year,
it returns a 1 and if not it returns 0. If there is an error, it returns
undef.

=item day_of_year

This function is meant to replace the Date::Calc::Day_of_Year routine. It
behaves the same way, returning a day of year taking into account leap years.

=item doy_to_ymd

Converts day of year to year, month, and day numbers. That is, it is the 
inverse of day_of_year.

=item add_delta_days

This function is meant to replace Date:Calc::Add_Delta_Days function. Given
the year, month, day, and a delta days (positive or negative), it returns
the new year, month and day.

=item days_in_year

Simple helper function that returns the number of days in the year, either 365
or 366.

=item day_of_week

This functions returns the day of week number where '1' is Monday, '2' is
Tuesday, ... '7' is Sunday. This mimics the behavior of 
Date::Calc::Day_of_Week(). The function is reliable for years after 1970.

=item add_delta_dhms

This function behaves like Date::Calc::Add_Delta_DHMS(). Given the year, month,
day, hour, minute, second; and delta days, hours, minutes, and seconds, it 
returns the new year, month, day, hour, minute, and second. The function
is reliable for years after 1970.

=item delta_dhms

This function behaves like Date::Calc::Delta_DHMS(). Given two dates and times,
it returns the delta days, hours, minutes, and seconds. And like the Date::Calc
equivalent, it returns positive values when the first date/time is EARLIER
than the second date/time; it returns ALL negative values when the reverse
is true.

=item seconds_to_dhms

Helper function that converts seconds into the equivalent number of days,
hours, minutes, and remainder seconds.

=item get_data_times

Returns an array of data start and end time pairs in CCSDS date/time string 
format. Each pair is delimited by a comma. It is similar to the old and
deprecated getDataTimes, except it will return multiple start/end time pairs 
when the data temporal coverage is less than the processing period. The inputs 
are $Coverage, the temporal coverage in seconds of the data whose start and 
end times are to be retrieved; $ProcessStartTime, a CCSDS string representing 
the processing start time; $ProcessingPeriod, the processing period in 
seconds; $Currency describes whether the times retrieved should be 
contemporaneous with the current processing period, or be the times for the 
previous n or following n granules (valids are CURR, PREVn, FOLLn where 
n = 1, 2,...); and $Boundary is one of START_OF_WEEK, START_OF_DAY, 
START_OF_6HOUR, START_OF_HOUR, START_OF_MIN, and START_OF_SEC and refers to 
the boundary against which the data's data time is specified.

=item getNearestTimeBoundary

Returns a CCSDS time string representing a floor function to the nearest
earlier time before the one specified in $CCSDS_str. $Boundary is 
one of START_OF_WEEK, START_OF_DAY, START_OF_6HOUR, START_OF_HOUR, 
START_OF_MIN, and START_OF_SEC and refers to the boundary against which the 
data's data time is specified and may include a + or - offset in seconds; 
$Coverage is the temporal coverage in seconds of the data; and $Periods 
allows you to specify multiplicity in how many times the floor is applied 
(1 meaning the nearest time boundary, 2 meaning go back one more increment 
earlier, etc.).

=item get_filename_pattern

Returns a string containing a glob pattern with which to search files of a 
particular data type having a file name with embedded time information. 
$data_start_time is a CCSDS string representing the data's start time and 
date and $template is a pattern template which may contain these items that 
will be replaced: %YY four-digit year, %jjj three-digit day of year, %mm 
month number, %dd day in month number, %HH hour (24-hour clock), %MM minutes, 
or %SS seconds. The remaining part of the template will be preserved in 
the returned pattern.

=item CCSDStoy

Given a date/time string in CCSDS format, returns the 2-digit year number
(similar to %y in the date command format option).

=item CCSDStoY

Given a date/time string in CCSDS format, returns the 4-digit year number
(similar to %Y in the date command format option).

=item CCSDStom

Given a date/time string in CCSDS format, returns the month number (00 - 12)
(similar to %m in the date command format option).

=item CCSDStod

Given a date/time string in CCSDS format, returns the day number (01 - 31)
(similar to %d in the date command format option).

=item CCSDStoH

Given a date/time string in CCSDS format, returns the hours on a 24-hour clock
(00 - 23) (similar to %H in the date command format option).

=item CCSDStoM

Given a date/time string in CCSDS format, returns the minutes (00 - 59) 
(similar to %M in the date command format option).

=item CCSDStoS

Given a date/time string in CCSDS format, returns the seconds (00 - 59) 
(similar to %S in the date command format option).

=item CCSDStoj

Given a date/time string in CCSDS format, returns the day of year (000 - 366)
(similar to %j in the date command format option).

=item CCSDStob

Given a date/time string in CCSDS format, returns the abbreviated month name
(Jan, Feb, Mar, ...) (similar to %b in the date command format option).

=item CCSDStoB

Given a date/time string in CCSDS format, returns the full month name
(January, February, March, ...) (similar to %B in the date command format 
option).

=item CCSDStou

Given a date/time string in CCSDS format, returns the day of week (1 - 7 with
Monday being 1) (similar to %u in the date command format option).

=item format_CCSDS_to_compare

This modifies the CCSDS formatted date/time so that a simple string compare
can be done, simplifying date comparisons.  To do this, it strips off the final
Z if it exists and reformats the seconds fields to %09.6f.

=back

=head1 EXAMPLES

"2000-06-09T10:00:00Z" = S4P::TimeTools::CCSDSa_DateFloor("2000-06-09T10:12:03Z", 
"hour", 1)

"2000-06-09T09:00:00Z" = S4P::TimeTools::CCSDSa_DateFloor("2000-06-09T10:12:03Z", 
"hour", 2)

"2000-06-09T00:00:00Z" = S4P::TimeTools::CCSDSa_DateFloor("2000-06-09T10:12:03Z", 
"day", 1)

"2000-06-01T00:00:00Z" = S4P::TimeTools::CCSDSa_DateFloor("2000-06-09T10:12:03Z", 
"month", 1)

"2000-04-01T00:00:00Z" = S4P::TimeTools::CCSDSa_DateFloor("2000-06-09T10:12:03Z", 
"month", 3)

"2000-01-01T00:00:00Z" = S4P::TimeTools::CCSDSa_DateFloor("2000-06-09T10:12:03Z", 
"year", 1)

"ERROR"                = S4P::TimeTools::CCSDSa_DateFloor("2000-06-0910:12:03Z", 
"year", 1)

(Note missing 'T' between date and time.)

    my ($Coverage, $ProcessStartTime, $ProcessingPeriod, $Currency, $Boundary, $Template) = @_;

"MOD021KM.A2000348.1200.*"  = S4P::TimeTools::getFilenamePattern(21600, 
"2000-12-13T14:45:00Z", 300, 0, "CURR", "START_OF_DAY", 
"MOD021KM.A%YYYY%jjj.%HH%MM.*")

=head1 LIMITATIONS

CCSDSa_DateRound does not handle leap seconds.  If the number of seconds is
86400 it assumes it is in the next day. Deal with it.

=head1 AUTHORS

Stephen Berrick - NASA/GSFC, Code 610.2

Chris Lynnes - NASA/GSFC, Code 610.2

=head1 TO DO

More complete man page as well as more complete internal documentation 
throughout.

More error checking.

Log file bundling

=cut

################################################################################
# TimeTools.pm,v 1.4 2010/05/14 14:00:45 glei Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P::TimeTools;

use S4P;
use Time::Local;
use strict;
my $timestamp_pattern = '\d\d\d\d-[01]\d-[0-3]\d[ T][0-2]\d:[0-5]\d:[0-5]\dZ*';
1;

################################################################################

sub CCSDSa_DateAdd {

### Input: Date string of the form YYYY-MM-DDThh:mm:ssZ
###        Number of seconds to add
### Returns: New date string with seconds added

    my ($date_str, $increment) = @_;

    my ($new_year, $new_month, $new_day, $new_hour, $new_min, $new_sec);

    my ($year, $month, $day, $hour, $min, $sec, $error) = CCSDSa_DateParse($date_str);
    if ( $error == 1 ) {
        return "ERROR";
    }

    if ( $year != 0 ) {
        ($new_year, $new_month, $new_day, $new_hour, $new_min, $new_sec) = 
            S4P::TimeTools::add_delta_dhms($year, $month, $day, $hour, $min, $sec,
                           0, 0, 0, $increment);

    }

    my $new_date_str = S4P::TimeTools::CCSDSa_DateUnparse($new_year, $new_month, $new_day, $new_hour, $new_min, $new_sec);
      
    return $new_date_str;
}

sub CCSDSa_DateCompare {
 
### Input: Date string 1 of the form YYYY-MM-DDThh:mm:ssZ
###        Date string 2 of the form YYYY-MM-DDThh:mm:ssZ
### Returns: +1 if date string 1 is earlier than date string 2
###          -1 if date string 1 is later than date string 2
###           0 if date string 1 is same date string 2
###           2 if comparison cannot be determined

    my ($date_str1, $date_str2) = @_;
    my $ret;

### Truncate to nearest second by removing any fractional component

    $date_str1 =~ s/\.[0-9]+Z$/Z/;
    $date_str2 =~ s/\.[0-9]+Z$/Z/;

    if ( $date_str1 lt $date_str2 ) {
        $ret = 1;
    } elsif ( $date_str1 gt $date_str2 ) {
        $ret = -1;
    } elsif ( $date_str1 eq $date_str2 ) {
        $ret = 0;
    } else {
        $ret = 2;
    }

    return $ret;
}

sub CCSDSa_DateParse {

### Input: Date string of the form YYYY-MM-DDThh:mm:ssZ
### Returns: Array with components parsed into 
###          ($year, $month, $day, $hours, $minutes, $seconds, $error)
###          If successful, $error = 0, if parsing failed, $error = 1

    my ($date_str) = $_[0];

    if ( $date_str =~ /([0123][0-9][0-9][0-9])-([01][0-9])-([0123][0-9])T([012][0-9]):([0-5][0-9]):([0-5][0-9]\.?\d*)Z/ ) {
        my $year  = $1;
        my $month = $2;
        my $day   = $3;
        my $hour  = $4;
        my $min   = $5;
        my $sec   = $6;
  
        return wantarray ? ($year, $month, $day, $hour, $min, $sec, 0) : 1;
    } else {
        return wantarray ? (0, 0, 0, 0, 0, 0, 1) : 0;
    }
}

sub CCSDSa_DateFloor {

    my ($date_str, $interval, $mult) = @_;

    my ($year, $month, $day, $hour, $min, $sec, $error);

    if ( $interval eq "hour" ) {
        my $str = S4P::TimeTools::CCSDSa_DateAdd($date_str, -(3600*($mult-1)));
        S4P::logger("DEBUG", "CCSDSa_DateFloor: str: [$str]");
        ($year, $month, $day, $hour, $min, $sec, $error) = S4P::TimeTools::CCSDSa_DateParse($str);
        $min = 0;
        $sec = 0;
    } elsif ( $interval eq "min" ) {
        my $str = S4P::TimeTools::CCSDSa_DateAdd($date_str, -(60*($mult-1)));
        S4P::logger("DEBUG", "CCSDSa_DateFloor: str: [$str]");
        ($year, $month, $day, $hour, $min, $sec, $error) = S4P::TimeTools::CCSDSa_DateParse($str);
        $sec = 0;
    } elsif ( $interval eq "sec" ) {
####### Skip actually doing anything since the smallest time we track is to
####### the second, not the fractional second as was once thought
        my $str = $date_str;
        S4P::logger("DEBUG", "CCSDSa_DateFloor: str: [$str]");
        ($year, $month, $day, $hour, $min, $sec, $error) = S4P::TimeTools::CCSDSa_DateParse($str);
    } elsif ( $interval eq "day" ) {
        my $str = S4P::TimeTools::CCSDSa_DateAdd($date_str, -(86400*($mult-1)));
        S4P::logger("DEBUG", "CCSDSa_DateFloor: str: [$str]");
        ($year, $month, $day, $hour, $min, $sec, $error) = S4P::TimeTools::CCSDSa_DateParse($str);
        $hour = "0";
        $min = "0";
        $sec = "0";
    } elsif ( $interval eq "week" ) {
        ($year, $month, $day, $hour, $min, $sec, $error) = S4P::TimeTools::CCSDSa_DateParse($date_str);
        my $dow = S4P::TimeTools::day_of_week($year, $month, $day);

####### The S4P::TimeTools::day_of_week returns a number 1 through 7 where 1 is for 
####### Monday and 7 is for Sunday. We, however, want the week to start at the 
####### beginning of Sunday and end at the end of Saturday. To get this, we 
####### want $dow to contain a 1 for Sunday and a 7 for Saturday. Thus, the 
####### following:

        if ( $dow == 7 ) {
            $dow = 1;
        } else {
            $dow += 1;
        }
        my $increment = ( ($dow-1) + ($mult-1)*7 ) * 86400;
        my $new_date = S4P::TimeTools::CCSDSa_DateAdd($date_str, -($increment));
        ($year, $month, $day, $hour, $min, $sec, $error) = S4P::TimeTools::CCSDSa_DateParse($new_date);
        $hour = "0";
        $min = "0";
        $sec = "0";
    } elsif ( $interval eq "month" ) {
        ($year, $month, $day, $hour, $min, $sec, $error) = S4P::TimeTools::CCSDSa_DateParse($date_str);
        $month -= ($mult-1);
        if ($month < 1) {
            $month += 12;
            $year--;
        }
        $day = 1;
        $hour = 0;
        $min = 0;
        $sec = 0;
    } elsif ( $interval eq "year" ) {
        ($year, $month, $day, $hour, $min, $sec, $error) = S4P::TimeTools::CCSDSa_DateParse($date_str);
        $year = $year - ($mult-1);
        $month = 1;
        $day = 1;
        $hour = 0;
        $min = 0;
        $sec = 0;
    } else {
        return "ERROR";
    }

    if ( $error == 1 ) {
        return "ERROR";
    }

    my $d = CCSDSa_DateUnparse($year, $month, $day, $hour, $min, $sec);
    S4P::logger("DEBUG", "CCSDSa_DateFloor: returning with [$d]");

    return $d;
   
}

sub CCSDSa_DateRound {
    my ($ccsds_date, $increment) = @_;
    my ($year, $month, $day, $hour, $minute, $second) = 
        CCSDSa_DateParse($ccsds_date);
    my $sec_in_day = $hour * 3600 + $minute * 60 + $second;
    my $sec_r = int($sec_in_day / $increment + 0.5) * $increment;
    if ($sec_r >= 86400) {
        ($year, $month, $day) = S4P::TimeTools::add_delta_days($year, $month, $day, 1);
        $sec_r -= 86400;
    }
    my $hour_r = $sec_r / 3600;
    my $minute_r = ($sec_r / 60) % 60;
    return CCSDSa_DateUnparse($year, $month, $day, $hour_r, $minute_r, 
        $sec_r % 60);
}

sub CCSDSa_DateFloorB {
    my ($ccsds_date, $increment) = @_;
    my $round = CCSDSa_DateRound($ccsds_date, $increment);
    # If we rounded down, take the round. If up, subtract $increment
    return (($round le $ccsds_date) ? $round
        : CCSDSa_DateAdd($round, -$increment));
}
#####################################################################
# CCSDSa_DateBins($start, $stop, $increment)
#--------------------------------------------------------------------
# Returns an array of CCSDSa date/times between $start and $stop spaced
# at $increment apart.  The input start and stop are in CCSDSa format.
# If stop time falls at an increment boundary, it is not included.
#====================================================================
sub CCSDSa_DateBins {
    my ($start, $stop, $increment) = @_;
    my @times;
    my $datetime = $start;
    push @times, $start;
    while ($datetime lt $stop) {
        $datetime = S4P::TimeTools::CCSDSa_DateAdd($datetime, $increment);
        push @times, $datetime;
    }
    # Last one was one too many
    pop @times;
    return @times;
}
sub CCSDSa_DateUnparse {
    
    my ($year, $month, $day, $hour, $min, $sec) = @_;

    my $ds = sprintf("%.4d-%.2d-%.2dT%.2d:%.2d:%.2dZ", $year, $month, $day, $hour, $min, $sec);

    return $ds;
}
sub CCSDSa_Now {
    my ($sec, $min, $hour, $day, $month, $year) = localtime(time);
    return CCSDSa_DateUnparse($year + 1900, $month + 1, $day, $hour, $min, $sec);
}
sub CCSDSa2timestamp {
    my $timestamp = shift;
    $timestamp =~ s/T/ / if ($timestamp =~ /\dT\d/);
    $timestamp =~ s/Z$// if ($timestamp =~ /Z$/);
    return $timestamp;
}
sub timestamp2CCSDSa {
    my $timestamp = shift;
    return '' if ($timestamp !~ /$timestamp_pattern/);
    $timestamp =~ s/ /T/ if ($timestamp !~ /\dT\d/);
    $timestamp =~ s/$/Z/ if ($timestamp !~ /Z$/);
    return $timestamp;
}
sub CCSDSa2yyyydddhhmmss {
    my $CCSDS_str = shift;
    my ($year, $month, $day, $hour, $min, $sec, $error) = S4P::TimeTools::CCSDSa_DateParse($CCSDS_str);
    return '' if $error;
    my $doy = S4P::TimeTools::day_of_year($year,$month,$day);
    return sprintf('%04d%03d%02d%02d%02d', $year, $doy, $hour, $min, $sec);
}
sub yyyydddhhmmss2CCSDSa {
    my $yyyydddhhmmss = shift;
    my $yyyy = substr($yyyydddhhmmss, 0, 4);
    my $ddd = substr($yyyydddhhmmss, 4, 3);
    my $hh = substr($yyyydddhhmmss, 7, 2);
    my $mm = substr($yyyydddhhmmss, 9, 2);
    my $ss = substr($yyyydddhhmmss, 11, 2);
    my ($year,$month,$day) = S4P::TimeTools::add_delta_days($yyyy,1, 1, $ddd - 1);
    return  sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year, $month,
        $day, $hh, $mm, $ss);
}
sub YYYYDDD_DateAdd {
    my ($year, $doy, $hour, $minute, $seconds, $increment) = @_;

    # Convert YYYY/DDD to YYYY/MM/DD
    my ($yr1, $month, $day) = S4P::TimeTools::add_delta_days($year, 1, 1, $doy-1);

    # Add seconds
    my ($yr2, $mon2, $day2, $hr2, $min2, $sec2) = S4P::TimeTools::add_delta_dhms(
        $yr1, $month, $day, $hour, $minute, $seconds, 0, 0, 0, $increment);

    # Figure out new day of year (and year in some cases)
    $doy = S4P::TimeTools::day_of_year($yr2,$mon2,$day2);

    return ($yr2, $doy, $hr2, $min2, $sec2);
}

################################################################################

sub get_data_times {

################################################################################
#                                get_data_times                                #
################################################################################
# PURPOSE: Determine the data start and end times based upon configuration     #
#          information for that data type and that PGE.                        #
################################################################################
# DESCRIPTION: get_data_times returns an array of data start and end times     #
#              based upon the data's coverage and boundary, along with the     #
#              currency and boundary of the particular input.                  #
################################################################################
# RETURN: @dtimes - Array of data start and end time/date pairs, comma         #
#                   delimited                                                  #
################################################################################
# CALLS: S4P::logger                                                           #
#        S4P::TimeTools::CCSDSa_DateAdd                                          #
#        S4P::TimeTools::CCSDSa_DateCompare                                      #
#        S4P::logger                                                           #
#        getNearestTimeBoundary                                                #
################################################################################

    my ($Coverage, $ProcessStartTime, $ProcessingPeriod, $Currency, $Boundary) = @_;

    S4P::logger("DEBUG", "get_data_times: Entering get_data_times() with Coverage: [$Coverage], ProcessStartTime: [$ProcessStartTime], ProcessingPeriod: [$ProcessingPeriod], Currency: [$Currency], Boundary: [$Boundary]");

    my ($start, $end, $nearest, $pp, $num_steps);
    my @dtimes = ();

    my $ProcessEndTime = S4P::TimeTools::CCSDSa_DateAdd($ProcessStartTime, $ProcessingPeriod);
    if ( $ProcessEndTime eq "ERROR" ) {
        S4P::logger("ERROR", "get_data_times: Could not compute processing end time.");
        return "ERROR,ERROR";
    }

### First, the simple case: the granule's coverage is the same as the 
### processing period

    if ( $Coverage == $ProcessingPeriod ) {

        S4P::logger("DEBUG", "get_data_times: Data coverage is EQUAL TO processing period");

        if ( $Currency eq "CURR" ) {
            $start = $ProcessStartTime;
            $end = S4P::TimeTools::CCSDSa_DateAdd($start, $Coverage);
            push(@dtimes, $start . "," . $end);
            if ( $end eq "ERROR" ) {
                S4P::logger("ERROR", "get_data_times: Could not compute end time for a current input granule.");
            }
        } elsif ( $Currency =~ /^PREV([0-9]+)/ ) {
            $num_steps = $1;
            $start = S4P::TimeTools::CCSDSa_DateAdd($ProcessStartTime, -($Coverage*$num_steps));
            if ( $end eq "ERROR" ) {
                S4P::logger("ERROR", "get_data_times: Could not compute start time for a previous input granule.");
            }
            $end = S4P::TimeTools::CCSDSa_DateAdd($start, $Coverage);
            if ( $end eq "ERROR" ) {
                S4P::logger("ERROR", "get_data_times: Could not compute end time for a previous input granule.");
            }
            push(@dtimes, $start . "," . $end);
        } elsif ( $Currency =~ /^FOLL([0-9]+)/ ) {
            $num_steps = $1;
            $start = S4P::TimeTools::CCSDSa_DateAdd($ProcessStartTime, ($Coverage*$num_steps));
            if ( $end eq "ERROR" ) {
                S4P::logger("ERROR", "get_data_times: Could not compute start time for a following input granule.");
            }
            $end = S4P::TimeTools::CCSDSa_DateAdd($start, $Coverage);
            if ( $end eq "ERROR" ) {
                S4P::logger("ERROR", "get_data_times: Could not compute end time for a following input granule.");
            }
            push(@dtimes, $start . "," . $end);
        } else {
            S4P::logger("ERROR", "get_data_times: Could not parse currency: $Currency\nShould be set to CURR, PREVn, or FOLLn (n = 1, 2,...).");
            $start = "ERROR";
            $end   = "ERROR";
            push(@dtimes, $start . "," . $end);
        }
    } elsif ( $Coverage > $ProcessingPeriod ) {

        S4P::logger("DEBUG", "get_data_times: Data coverage is GREATER THAN processing period");

        if ( $Currency =~ /^PREV([0-9]+)/ ) {
            $num_steps = $1 + 1;
            S4P::logger("DEBUG", "get_data_times: Calling getNearestTimeBoundary() with ProcessStartTime: [$ProcessStartTime], Boundary: [$Boundary], Coverage: [$Coverage]");
            $nearest = S4P::TimeTools::getNearestTimeBoundary($ProcessStartTime, $Boundary, $Coverage, -($num_steps));
            $start = S4P::TimeTools::CCSDSa_DateAdd($nearest, -( ($num_steps-1)*$Coverage ));
            $end   = S4P::TimeTools::CCSDSa_DateAdd($start, $Coverage);
            push(@dtimes, $start . "," . $end);
        } elsif ( $Currency eq "CURR" ) {
            $num_steps = 1;
            S4P::logger("DEBUG", "get_data_times: Calling getNearestTimeBoundary() with ProcessStartTime: [$ProcessStartTime], Boundary: [$Boundary], Coverage: [$Coverage]");
            $nearest = S4P::TimeTools::getNearestTimeBoundary($ProcessStartTime, $Boundary, $Coverage, $num_steps);
            $start = $nearest;
            $end   = S4P::TimeTools::CCSDSa_DateAdd($start, $Coverage);
            push(@dtimes, $start . "," . $end);
        } elsif ( $Currency =~ /^FOLL([0-9]+)/ ) {
            $num_steps = $1 - 1;
            S4P::logger("DEBUG", "get_data_times: Calling getNearestTimeBoundary() with ProcessStartTime: [$ProcessStartTime], Boundary: [$Boundary], Coverage: [$Coverage]");
            $nearest = S4P::TimeTools::getNearestTimeBoundary($ProcessStartTime, $Boundary, $Coverage, -($num_steps));
            print "\nProcessStartTime: $ProcessStartTime\n";
            print "nearest: $nearest\n";
            $start = S4P::TimeTools::CCSDSa_DateAdd($nearest, +( ($num_steps+1)*$Coverage ));
            $end   = S4P::TimeTools::CCSDSa_DateAdd($start, $Coverage);
            push(@dtimes, $start . "," . $end);
        } else {
            $start = "ERROR";
            $end   = "ERROR";
            push(@dtimes, $start . "," . $end);
        } 

    } else {

        S4P::logger("DEBUG", "get_data_times: Data coverage is LESS THAN processing period");

        if ( $Currency =~ /^PREV([0-9]+)/ ) {
            $num_steps = $1 + 1;
            S4P::logger("DEBUG", "get_data_times: Calling getNearestTimeBoundary() with ProcessStartTime: [$ProcessStartTime], Boundary: [$Boundary], Coverage: [$Coverage]");
            $nearest = S4P::TimeTools::getNearestTimeBoundary($ProcessStartTime, $Boundary, $Coverage, -($num_steps));
            $start = S4P::TimeTools::CCSDSa_DateAdd($nearest, -( ($num_steps-1)*$Coverage ));
            $end   = S4P::TimeTools::CCSDSa_DateAdd($start, $Coverage);
            push(@dtimes, $start . "," . $end);
        } elsif ( $Currency eq "CURR" ) {
            $num_steps = 1;
            S4P::logger("DEBUG", "get_data_times: ProcessStartTime: [$ProcessStartTime]");
            S4P::logger("DEBUG", "get_data_times: ProcessEndTime: [$ProcessEndTime]");
            S4P::logger("DEBUG", "get_data_times: Coverage: [$Coverage]");
            for ( 
                    my $begin = $ProcessStartTime; 
                    ( S4P::TimeTools::CCSDSa_DateCompare($begin, $ProcessEndTime) == 1); 
                    $begin = S4P::TimeTools::CCSDSa_DateAdd($begin, $Coverage) 
                ) {
                    S4P::logger("DEBUG", "get_data_times: Calling getNearestTimeBoundary() with begin: [$begin], Boundary: [$Boundary], Coverage: [$Coverage]");
                    $nearest = getNearestTimeBoundary($begin, $Boundary, $Coverage, $num_steps);
                    $start = $nearest;
                    $end   = S4P::TimeTools::CCSDSa_DateAdd($start, $Coverage);
                    push(@dtimes, $start . "," . $end);
            }
        } elsif ( $Currency =~ /^FOLL([0-9]+)/ ) {
            $num_steps = $1 - 1;
            S4P::logger("DEBUG", "get_data_times: Calling CCSDSa_DateAdd() with ProcessEndTime: [$ProcessEndTime], Coverage: [-$Coverage]");
            my $begin = S4P::TimeTools::CCSDSa_DateAdd($ProcessEndTime, -$Coverage);
            S4P::logger("DEBUG", "get_data_times: Calling getNearestTimeBoundary() with begin: [$begin], Boundary: [$Boundary], Coverage: [$Coverage]");
            $nearest = S4P::TimeTools::getNearestTimeBoundary($begin, $Boundary, $Coverage, -($num_steps));
            $start = S4P::TimeTools::CCSDSa_DateAdd($nearest, +( ($num_steps+1)*$Coverage ));
            $end   = S4P::TimeTools::CCSDSa_DateAdd($start, $Coverage);
            push(@dtimes, $start . "," . $end);
        } else {
            $start = "ERROR";
            $end   = "ERROR";
            push(@dtimes, $start . "," . $end);
        }
    }

    return @dtimes;
}

sub getNearestTimeBoundary {

################################################################################
#                            getNearestTimeBoundary                            #
################################################################################
# PURPOSE: To find the nearest time boundary                                   #
################################################################################
# DESCRIPTION: getNearestTimeBoundary works like a floor function, basically   #
#              rounding a date/time to the nearest boundary, which can be one  #
#              of {START_OF_WEEK, START_OF_DAY, START_OF_WEEK, START_OF_6HOUR, #
#              START_OF_HOUR, START_OF_MIN, START_OF_SEC} with an optional     #
#              + or - an offset specified in seconds (e.g. START_OF_DAY-3600). #
#              The input, $num_periods, allows multiplicity, i.e. to go back   #
#              to ($num_periods+1) boundaries before the nearest.              #
#                                                                              #
# EXAMPLES: Input:  2000-08-09T12:02:00Z, START_OF_DAY, 7200, 1                #
#           Output: 2000-08-09T12:00:00Z                                       #
#           Input:  2000-08-09T12:02:00Z, START_OF_DAY, 7200, 2                #
#           Output: 2000-08-09T10:00:00Z                                       #
#           Input:  2000-08-09T02:12:00Z, START_OF_HOUR, 300 1                 #
#           Output: 2000-08-09T02:10:00Z                                       #
#           Input:  2000-08-09T02:12:00Z, START_OF_HOUR, 300 -1                #
#           Output: 2000-08-09T02:15:00Z                                       #
#           Input:  2000-08-09T02:12:00Z, START_OF_HOUR, 300 2                 #
#           Output: 2000-08-09T02:05:00Z                                       #
#           Input:  2000-08-09T02:12:00Z, START_OF_HOUR, 300 -2                #
#           Output: 2000-08-09T02:20:00Z                                       #
################################################################################
# RETURN: $prev_time - The time corresponding to the "floor"                   #
################################################################################
# CALLS: S4P::logger                                                           #
#        S4P::TimeTools::CCSDSa_DateFloor                                        #
#        S4P::TimeTools::CCSDSa_DateAdd                                          #
#        S4P::TimeTools::CCSDSa_DateCompare                                      #
################################################################################

    my ($date_str, $boundary, $coverage, $num_periods) = @_;

    my ($x, $prev_time, $new_time);

    my ($bound, $op, $offset) = split(/([+-])/, $boundary);
    $bound  =~ s/^\s+//;
    $op     =~ s/^\s+//;
    $offset =~ s/^\s+//;
    $bound  =~ s/\s+$//;
    $op     =~ s/\s+$//;
    $offset =~ s/\s+$//;
    if ( $offset eq "" or $offset eq undef ) {
        $offset = 0;
    }
    S4P::logger("DEBUG", "getNearestTimeBoundary: data_str: [$date_str], bound: [$bound], op: [$op], offset: [$offset]");

### We avoid boundary conditions by adding an extra unit in each of the 
### calculations below. That is, for START_OF_DAY, we floor it by a multiple
### of 2 days rather than 1:

    if ( $bound eq "START_OF_DAY" ) {
        $prev_time = S4P::TimeTools::CCSDSa_DateFloor($date_str, "day", 2);
    } elsif ( $bound eq "START_OF_WEEK" ) {
        $prev_time = S4P::TimeTools::CCSDSa_DateFloor($date_str, "week", 2);
    } elsif ( $bound eq "START_OF_HOUR" ) {
        $prev_time = S4P::TimeTools::CCSDSa_DateFloor($date_str, "hour", 2);
    } elsif ( $bound eq "START_OF_6HOUR" ) {
        $prev_time = S4P::TimeTools::CCSDSa_DateFloor($date_str, "hour", 12);
    } elsif ( $bound eq "START_OF_MIN" ) {
        $prev_time = S4P::TimeTools::CCSDSa_DateFloor($date_str, "min", 2);
    } elsif ( $bound eq "START_OF_SEC" ) {
        $prev_time = S4P::TimeTools::CCSDSa_DateFloor($date_str, "sec", 2);
    }
  
### Now, account for any offset to the boundary

    S4P::logger("DEBUG", "getNearestTimeBoundary: prev_time before offset: [$prev_time]");
    if ( $offset != 0 ) {
        if ( $op eq '+' ) {
            $prev_time = S4P::TimeTools::CCSDSa_DateAdd($prev_time, $offset);
        } elsif ( $op eq '-' ) {
            $prev_time = S4P::TimeTools::CCSDSa_DateAdd($prev_time, -$offset);
        } else {
            S4P::perish(1, "getNearestTimeBoundary: Invalid operand in boundary offset specified: [$op]");
        }
    }
    S4P::logger("DEBUG", "getNearestTimeBoundary: prev_time after offset: [$prev_time]");

### Keep adding granule coverage times to the time boundary until
### the time is greater than the processing start time, $date_str

    $new_time = $prev_time;
    do {
        $prev_time = $new_time;
        $new_time = S4P::TimeTools::CCSDSa_DateAdd($prev_time, $coverage);
        S4P::logger("DEBUG", "getNearestTimeBoundary: new_time: [$new_time]");
    } while ( S4P::TimeTools::CCSDSa_DateCompare($new_time, $date_str) == 1 or 
              S4P::TimeTools::CCSDSa_DateCompare($new_time, $date_str) == 0 );

    S4P::logger("DEBUG", "getNearestTimeBoundary: returning with [$prev_time]");
    return $prev_time;

}

sub get_filename_pattern {

################################################################################
#                             get_filename_pattern                             #
################################################################################
# PURPOSE: To produce a file name glob pattern with which to search for files  #
################################################################################
# DESCRIPTION: get_filename_pattern uses a pattern template and the data start #
#              time to construct and return a file name pattern that can then  #
#              be used for file globbing.                                      #
################################################################################
# RETURN: $template - The file name pattern                                    #
################################################################################
# CALLS: S4P::TimeTools::CCSDSa_DateParse                                        #
################################################################################

    my ($data_start_time, $template) = @_;

    my ($year, $month, $day, $hour, $min, $sec, $error) =
        S4P::TimeTools::CCSDSa_DateParse($data_start_time);

    if ( $error ) {
        return "ERROR";
    }

    my $doy = S4P::TimeTools::day_of_year($year,$month,$day);
  
### We want to always have 3-digit day of year values

    if ( length($doy) == 2 ) { $doy = "0"  . $doy; }
    if ( length($doy) == 1 ) { $doy = "00" . $doy; }

    $template =~ s/%YYYY/$year/g;
    $template =~ s/%dd/$day/g;
    $template =~ s/%jjj/$doy/g;
    $template =~ s/%MM/$min/g;
    $template =~ s/%HH/$hour/g;
    $template =~ s/%SS/$sec/g;

    return $template;
}

sub CCSDSa_Diff {

    my ($date1, $date2) = @_;

    my ($year1, $month1, $day1, $hour1, $min1, $sec1, $error1) = 
        S4P::TimeTools::CCSDSa_DateParse($date1);
    
    my ($year2, $month2, $day2, $hour2, $min2, $sec2, $error2) = 
        S4P::TimeTools::CCSDSa_DateParse($date2);

    if ( $error1 or $error2 ) {
        return;		# returns an undef
    }

    my ($days, $hours, $mins, $secs) = 
        S4P::TimeTools::delta_dhms($year1, $month1, $day1, $hour1, $min1, $sec1,
                              $year2, $month2, $day2, $hour2, $min2, $sec2);

    return (86400 * $days) + (3600 * $hours) + (60 * $mins) + $secs;
}

sub is_leapyear {

    my $year = shift;

    if ( $year < 0 ) { return undef; }

### First, rule out any year not evenly divisible by 4

    if ( ($year % 4) != 0 ) {
        return 0;
    }

### At this point, it MAY be a leap year

    if ( ($year % 100) == 0 ) {
        if ( ($year % 400) == 0 ) {
            return 1;
        } else {
            return 0;
        }
    }

    return 1;
}

sub day_of_year {

    my ($year, $month, $day) = @_;

    $month =~ s/^0+//;

    my %days_per_month = (
        '1'  => 31,
        '2'  => 28,
        '3'  => 31,
        '4'  => 30,
        '5'  => 31,
        '6'  => 30,
        '7'  => 31,
        '8'  => 31,
        '9'  => 30,
        '10' => 31,
        '11' => 30,
        '12' => 31,
    );

    if ( S4P::TimeTools::is_leapyear($year) ) {
        $days_per_month{'2'} = 29;
    }

    if ( $day < 1 or $day > $days_per_month{$month} ) {
        return undef;
    }
    if ( $month > 12 or $month < 1 ) {
        return undef;
    }
    if ( $year < 1 ) {
        return undef;
    }

    my $sum = 0;
    for (my $i = 1; $i < $month; $i++) {
        $sum += $days_per_month{$i};
    }

    $sum += $day;

    return $sum;

}

sub add_delta_days {

    my ($year, $month, $day, $delta) = @_;

    my $old_doy = S4P::TimeTools::day_of_year($year, $month, $day);
    unless ( $old_doy ) {
        return ("ERROR", "ERROR", "ERROR");
    }
    my $new_doy = $old_doy + $delta;

### If we end up with doy of zero, it is really the last day of the previous
### year

    if ( $new_doy == 0 ) {
        $year--;
        if ( S4P::TimeTools::is_leapyear($year) ) {
            $new_doy = 366;
        } else {
            $new_doy = 365;
        }
    }

    while ( $new_doy > S4P::TimeTools::days_in_year($year) or $new_doy < 1 ) {

####### Notice the ordering of statements within the if block is different
####### depending upon case

        if ( $new_doy > S4P::TimeTools::days_in_year($year) ) {

            $new_doy = $new_doy - S4P::TimeTools::days_in_year($year);
            $year++;
        } else {
            $year--;
            $new_doy = $new_doy + S4P::TimeTools::days_in_year($year);
        }
    }

    my ($newyear, $newmonth, $newday) = S4P::TimeTools::doy_to_ymd($new_doy, $year);

    return ($newyear, $newmonth, $newday);
}

sub days_in_year {

    my $year = shift;

    my $max;
    if ( is_leapyear($year) ) {
        $max = 366;
    } else {
        $max = 365;
    }

    return $max;
}

sub doy_to_ymd {

    my ($doy, $year) = @_;

    my $month;
    my $day;

    my %days_per_month = (
        '1'  => 31,
        '2'  => 28,
        '3'  => 31,
        '4'  => 30,
        '5'  => 31,
        '6'  => 30,
        '7'  => 31,
        '8'  => 31,
        '9'  => 30,
        '10' => 31,
        '11' => 30,
        '12' => 31,
    );

    my $leap_flag = undef;
    if ( is_leapyear($year) ) {
        $days_per_month{'2'} = 29;
        $leap_flag = 1;
    }

    if ( $leap_flag ) {
        if ( $doy < 0 or $doy > 366 ) {
            return ("ERROR", "ERROR", "ERROR");
        }
    } else {
        if ( $doy < 0 or $doy > 365 ) {
            return ("ERROR", "ERROR", "ERROR");
        }
    }

    my $sum = 0;
    for (my $i = 1; $i < 13; $i++) {
        $sum += $days_per_month{$i};
        if ( $sum >= $doy ) {
            $month = $i;
            $day = $days_per_month{$i} - ($sum - $doy);
            return ($year, $month, $day);
        }
    }

    return ("ERROR", "ERROR", "ERROR");

}

sub day_of_week {
    my ($year, $month, $day) = @_;
    my $epoch = timegm(0, 0, 0, $day, $month-1, $year);
    my $day_of_week = (gmtime($epoch))[6];
    if ($day_of_week == 0) { $day_of_week = 7; }
    return $day_of_week;
}

sub add_delta_dhms {
    my($year, $month, $day, $hour, $min, $sec, $dday, $dhour, $dmin, $dsec) = @_;

    my $total_seconds = (86400*$dday) + (3600*$dhour) + (60*$dmin) + $dsec;

    my $epoch = $total_seconds + timegm($sec, $min, $hour, $day, $month-1, $year);
    my ($new_sec, $new_min, $new_hour, $new_day, $new_month, $new_year) =
        gmtime($epoch);
    return ($new_year+1900, $new_month+1, $new_day, $new_hour, $new_min, $new_sec);
}

sub delta_dhms {

    my ($year1, $month1, $day1, $hour1, $min1, $sec1,
        $year2, $month2, $day2, $hour2, $min2, $sec2) = @_;

### Need to use timegm() here rather than timelocal() to avoid daylight savings
### time issues

    my $time1 = timegm($sec1, $min1, $hour1, $day1, $month1-1, $year1);
    my $time2 = timegm($sec2, $min2, $hour2, $day2, $month2-1, $year2);

    return S4P::TimeTools::seconds_to_dhms($time2 - $time1);

}
sub seconds_to_dhms {

    my $secs = shift;

    my $days = int($secs/86400);
    $secs -= ($days*86400);
    my $hours = int($secs/3600);
    $secs -= ($hours*3600);
    my $mins = int($secs/60);
    $secs -= ($mins*60);

    return ($days, $hours, $mins, $secs);
}
# Convert default Sybase database time string to CCSDSa format
sub sybase2CCSDSa {
    my $s = shift;
    my ($yy, $mm, $dd, $hh, $min) = sybase2parts($s);
    return sprintf("%04d-%02d-%02dT%02d:%02d:00Z", $yy, $mm, $dd, $hh, $min);
}
# Convert default Sybase database time string to epochal time
sub sybase2epoch {
    my ($s, $gmt) = @_;
    my ($yy, $mm, $dd, $hh, $min) = sybase2parts($s);
    return ($gmt) ?
        timegm(0, $min, $hh, $dd, $mm-1, $yy) :
        timelocal(0, $min, $hh, $dd, $mm-1, $yy);
}
# Convert default Sybase database time string to individual time parts
sub sybase2parts {
    my $s = shift;
#   Mar  1 2003  5:59PM
    my @parts = split(/\s+/, $s);
    my @months = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
    my %months = map {($months[$_], $_+1)} 0..11;
    my $yy = $parts[2];
    my $mm = $months{$parts[0]};
    my $dd = $parts[1];
    my $t = $parts[3];
    my ($hh, $t1) = split(':', $t);
    $hh += 12 if ($t1 =~ /PM/ && $hh != 12);
    $hh -= 12 if ($t1 =~ /AM/ && $hh == 12);
    my $min = substr($t1,0,2);
    return ($yy, $mm, $dd, $hh, $min);
}

sub CCSDStoy {
    my $date_str = shift;
    return substr($date_str, 2, 2);
}
sub CCSDStoY {
    my $date_str = shift;
    return substr($date_str, 0, 4);
}
sub CCSDStom {
    my $date_str = shift;
    return substr($date_str, 5, 2);
}
sub CCSDStod {
    my $date_str = shift;
    return substr($date_str, 8, 2);
}
sub CCSDStoH {
    my $date_str = shift;
    return substr($date_str, 11, 2);
}
sub CCSDStoM {
    my $date_str = shift;
    return substr($date_str, 14, 2);
}
sub CCSDStoS {
    my $date_str = shift;
    return substr($date_str, 17, 2);
}
sub CCSDStoj {
    my $date_str = shift;
    my $month = CCSDStom($date_str);
    my $day   = CCSDStod($date_str);
    my $year  = CCSDStoY($date_str);
    my $doy = S4P::TimeTools::day_of_year($year, $month, $day);
    $doy = "00" . $doy if ( length($doy) == 1 );
    $doy =  "0" . $doy if ( length($doy) == 2 );
    return $doy;
}
sub CCSDStob {
    my $date_str = shift;
    my @months = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    my $month = CCSDStom($date_str);
    return $months[$month-1];
}
sub CCSDStou {
    my $date_str = shift;
    my $month = CCSDStom($date_str);
    my $day   = CCSDStod($date_str);
    my $year  = CCSDStoY($date_str);
    return S4P::TimeTools::day_of_week($year, $month, $day);
}
sub CCSDStoB {
    my $date_str = shift;
    my @months = ('January', 'February', 'March', 'April', 'May', 'June',
                  'July', 'August', 'September', 'October', 'November', 
                  'December');
    my $month = CCSDStom($date_str);
    return $months[$month-1];
}

sub format_CCSDS_to_compare {
    my @times = @_;

    # Strip of final Z and make seconds field uniform for comparison purposes.
    foreach (@times) {
        s/Z//;
        my @parts = split(':');
        my $secs = pop @parts;
        push @parts, sprintf("%09.6f", $secs);
        $_ = join(':', @parts);
    }
    return @times;
}

1;
