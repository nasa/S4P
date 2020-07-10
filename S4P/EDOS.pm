#!/usr/bin/perl

=head1 NAME

EDOS.pm - parse Level 0 construction records

=head1 SYNOPSIS

use S4P::EDOS;

my %met = S4P::EDOS::parse_construction_record($filename);

=head1 DESCRIPTION

B<parse_construction_record> parses level 0 construction records from EDOS.
For the construction record it parses until it hits a serious problem, like
a filled spare bit, bad CCSDS time code, etc.  

This returns a metadata hash, with attributes as keys.
So far, the supported attributes are:
  ShortName
  BeginningDateTime
  EndingDateTime
  ProductionDateTime
  NumberOfFiles
  PDS_ID
  LocalGranuleID
  Filenames (returns an anonymous array of filenames)

=head1 EXAMPLE

  use S4P::EDOS;
  my $file = shift;
  my %met = S4P::EDOS::parse_construction_record($file);
  foreach my $key(sort keys %met) {
      my $s = (ref $met{$key}) ? join(' ', @{$met{$key}}) : $met{$key};
      print "$key => $s\n";
  }


=head1 DIAGNOSTICS

In case of failure, return is undef.

=head1 BUGS

It is cavalier about leap seconds, which is to say, it doesn't address them.

=head1 AUTHOR

Christopher S Lynnes, NASA/GSFC, Code 610.2

=head1 CHANGELOG
08/01/06 J Pan     Corrected APID 414 mapping

=cut

################################################################################
# EDOS.pm,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_2
################################################################################

package S4P::EDOS;
use Math::BigInt;
use Math::BigFloat;
use Getopt::Std;
use S4P;
use S4P::TimeTools;
use strict;
our $reclen;
use Exporter qw(import);
our @EXPORT_OK = qw(getval pb5_time bin2dec cds_time cuc_time calday check_val spare parse_construction_record);
1;

sub parse_construction_record {
    my ($file) = shift;
    my $verbose = shift;
    unless (-f $file) {
        S4P::logger('ERROR', "File $file not found");
        return;
    }
    unless (open IN, $file) {
        S4P::logger('ERROR', "Cannot open file $file: $!");
        return;
    }
    local($/)=undef;
    my $rec = <IN>;
    close IN;
    my @vals = ();
    my @names = ();
    my $pos = 0;
    my ($i, $j);
    $reclen = length $rec;
    my %met;

    # Item 1
    push @names, "1: EDOS Major Software Version";
     S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, getval($rec, \$pos, 1, 'C');
     S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));
    push @names, "1: EDOS Minor Software Version";
     S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, getval($rec, \$pos, 1, 'C');
     S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

    # Item 2
    my $ncr_type = getval($rec, \$pos, 1, 'C', 1, 3, "2");
    push @names, "2: Construction Record Type Code";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, $ncr_type;
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));
    push @names, "2: Construction Record Type";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, ('PDS','EDS','EDS')[$ncr_type-1];
    S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

    # Item 3
    spare($rec, \$pos, 1, "3");

    # Item 4
    push @names, "4: PDS/EDS Identification";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    my $pds_id = getval($rec, \$pos, 36, 'A' x 36);
    push @vals, $pds_id;
    $met{'PDS_ID'} = $pds_id;
    $met{'LocalGranuleID'} = $pds_id;
    my $scs_start ;
    my $scs_stop ;
    S4P::logger('DEBUG', sprintf("%s\n", $pds_id));
    my $use_pb5 = !($pds_id =~ /^P157/); # Starting with SNPP, time codes will be CCSDS Segmented Day
    #$use_pb5 = 1;  # Comment this out once EDOS makes change

    # Item 5 / 6
    push @names, "6: Test Flag";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, getval($rec, \$pos, 1, 'b', 0, 1, "6");
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

    # Item 7
    spare($rec, \$pos, 1, "7-1");
    spare($rec, \$pos, 8, "7-2");

    # Item 8
    my $n_scs = getval($rec, \$pos, 2, 'n');
    push @names, "8: Number of SCS start/stop times";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, $n_scs;
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

    for ($i = 0; $i < $n_scs; $i++) {
        # Item 8-1
        spare($rec, \$pos, 1, "8-1") if ($use_pb5);

        # Item 8-2
        push @names, "  8-2: SCS $i start";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals, ($use_pb5) ? pb5_time($rec, \$pos) : cds_time($rec, \$pos);
        S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));
        unless ($scs_start) {
            $scs_start = pop @vals ;
            push @vals, $scs_start ;
        }

        # Item 8-3
        spare($rec, \$pos, 1, "8-3") if ($use_pb5);

        # Item 8-4
        push @names, "  8-4: SCS $i stop";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals, ($use_pb5) ? pb5_time($rec, \$pos) : cds_time($rec, \$pos);
        S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));
        unless ($scs_stop) {
            $scs_stop = pop @vals ;
            push @vals, $scs_stop ;
        }
    }
    $met{'SCS_StartTime'} = $scs_start ;
    $met{'SCS_StopTime'} = $scs_stop ;
    # Item 9
    push @names, "9: Number of octets of EDOS generated fill data";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, getval($rec, \$pos, 8, "N");
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

    # Item 10
    push @names, "10: Header/actual length discrepancies";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, getval($rec, \$pos, 4, "N");
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

    # Item 11
    push @names, "11: CCSDS Timecode / 2ndary header of 1st packet";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, cds_time($rec, \$pos);
    S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));
    $met{'BeginningDateTime'} = (@vals)[-1];

    # Item 12
    push @names, "12: CCSDS Timecode / 2ndary header of Last packet";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, cds_time($rec, \$pos);
    S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));
    $met{'EndingDateTime'} = (@vals)[-1];

    # Item 13
    spare($rec, \$pos, 1, "13") if ($use_pb5);

    # Item 14
    push @names, "14: ESH date/time annotation of 1st packet";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, ($use_pb5) ? pb5_time($rec, \$pos) : cds_time($rec, \$pos);
    S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

    # Item 15
    spare($rec, \$pos, 1, "15") if ($use_pb5);

    # Item 16
    push @names, "16: ESH date/time annotation of last packet";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, ($use_pb5) ? pb5_time($rec, \$pos) : cds_time($rec, \$pos);
    S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

    # Item 17
    push @names, "17: Packets from VCDUs corrected by R-S decoding";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, getval($rec, \$pos, 4, "N");
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

    # Item 18
    push @names, "18: Number of packets";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, getval($rec, \$pos, 4, "N");
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

    # Item 19
    push @names, "19: Number of octets";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, getval($rec, \$pos, 8, "N");
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

    # Item 20
    push @names, "20: Packets with SSC discontinuities";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, getval($rec, \$pos, 4, "N");
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

    # Item 21
    spare($rec, \$pos, 1, "21") if ($use_pb5);

    # Item 22
    push @names, "22: Time of completion";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    push @vals, ($use_pb5) ? pb5_time($rec, \$pos) : cds_time($rec, \$pos);
    S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));
    $met{'ProductionDateTime'} = (@vals)[-1];

    # Item 23
    spare($rec, \$pos, 7, "23");

    # Item 24
    push @names, "24: Number of APIDs";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    my $n_apids = getval($rec, \$pos, 1, "C", 1, 100, "24");
    push @vals, $n_apids;
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));
    for ($i = 0; $i < $n_apids; $i++) {
        # Item 24-1
        spare($rec, \$pos, 1, "24-1");
 
        # Item 24-2
        my $scid_apid = getval($rec, \$pos, 3, "B24");
        push @names, "  24-2: SCID[$i]";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals,  bin2dec(substr($scid_apid, 0, 8));
        S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));
        push @names, "  24-2: APID[$i]";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        my $apid = bin2dec(substr($scid_apid, 13, 11));
        push @vals, $apid;
        $met{'ShortName'} = apid2shortname($apid,$pds_id);
        S4P::logger('DEBUG', sprintf("%d (%s)\n", $apid, $met{'ShortName'}));

        # Item 24-3
        push @names, "  24-3: Byte offset to first packet";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals, getval($rec, \$pos, 8, "L");
        S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

        # Item 24-4
        spare($rec, \$pos, 3, "24-4");

        # Item 24-5
        push @names, "  24-5: Number of VCIDs (1-2)";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        my $n_vcids = getval($rec, \$pos, 1, "C", 1, 2, "24-5");
        push @vals, $n_vcids;
        S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

        for ($j = 0; $j < $n_vcids; $j++) {
            # Item 24-5.1
            spare($rec, \$pos, 2, "24-5.1");

            # Item 24-5.2
            my $vcdu_id = getval($rec, \$pos, 2, "B16");
            push @names, "    24-5.2: SCID";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, bin2dec(substr($vcdu_id, 2, 8));
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));
            push @names, "    24-5.2: VCID";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, bin2dec(substr($vcdu_id, 10, 6));
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));
        }
        # Item 24-6
        push @names, "  24-6: Packets with SSC Discontinuities (Gaps)";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        my $n_gaps = getval($rec, \$pos, 4, "N");
        push @vals, $n_gaps;
        S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

        for ($j = 0; $j < $n_gaps; $j++) {
            # Item 24-6.1
            push @names, "    24-6.1: Identity of 1st missing packet SSC";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, getval($rec, \$pos, 4, "N");
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

            # Item 24-6.2
            push @names, "    24-6.2: Byte offset into dataset to missing packet";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, getval($rec, \$pos, 8, "L");
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

            # Item 24-6.3
            push @names, "    24-6.3: Number of Packet SSCs missed";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, getval($rec, \$pos, 4, "N");
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

            # Item 24-6.4
            push @names, "    24-6.4: CCSDS timecode / secondary header, pre-gap";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, cds_time($rec, \$pos);
            S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

            # Item 24-6.5
            push @names, "    24-6.5: CCSDS timecode / secondary header, post-gap";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, cds_time($rec, \$pos);
            S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

	    skip($rec, \$pos, 1, "24-6.6");
	    skip($rec, \$pos, 7, "24-6.7");
	    skip($rec, \$pos, 1, "24-6.8");
	    skip($rec, \$pos, 7, "24-6.9");
#            # Item 24-6.6
#            spare($rec, \$pos, 1, "24-6.6") if ($use_pb5);
#
#            # Item 24-6.7
#            push @names, "    24-6.7: ESH timecode / secondary header, pre-gap";
#            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
#            push @vals, ($use_pb5) ? pb5_time($rec, \$pos) : cds_time($rec, \$pos);
#            S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));
#
#            # Item 24-6.8
#            spare($rec, \$pos, 1, "24-6.8") if ($use_pb5);
#
#            # Item 24-6.9
#            push @names, "    24-6.9: ESH timecode / secondary header, post-gap";
#            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
#            push @vals, ($use_pb5) ? pb5_time($rec, \$pos) : cds_time($rec, \$pos);
#            S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));
        }
        # Item 24-7
        push @names, "  24-7: Number of entries with fill data";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        my $n_fill = getval($rec, \$pos, 4, "N");
        push @vals, $n_fill;
        S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

        for ($j = 0; $j < $n_fill; $j++) {
            # Item 24-7.1
            push @names, "    24-7.1: SSC of packet with fill data";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, getval($rec, \$pos, 4, "N");
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

            # Item 24-7.2
            push @names, "    24-7.2: Offset of packet with fill data";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, getval($rec, \$pos, 8, "L");
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

            # Item 24-7.3
            push @names, "    24-7.3: Index to first fill octet";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, getval($rec, \$pos, 4, "N");
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));
        }
        # Item 24-8
        push @names, "  24-8: Number of fill octets";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals, getval($rec, \$pos, 8, "L");
        S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

        # Item 24-9
        push @names, "  24-9: Number of packet length discrepancies";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        my $n_pktlen = getval($rec, \$pos, 4, "N");
        push @vals, $n_pktlen;
        S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

        for ($j = 0; $j < $n_pktlen; $j++) {
            # Item 24-9.1
            push @names, "    24-9.1: SSC of packet with length discrepancy";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, getval($rec, \$pos, 4, "N");
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));
        }
        # Item 24-10
        push @names, "  24-10: CCSDS Time of secondary header of 1st packet";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals, cds_time($rec, \$pos);
        S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

        # Item 24-11
        push @names, "  24-11: CCSDS Time of secondary header of last packet";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals, cds_time($rec, \$pos);
        S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

	skip($rec, \$pos, 1, "24-12");
	skip($rec, \$pos, 7, "24-13");
	skip($rec, \$pos, 1, "24-14");
	skip($rec, \$pos, 7, "24-15");
#        # Item 24-12
#        spare($rec, \$pos, 1, "24-12") if ($use_pb5);
#
#        # Item 24-13
#        push @names, "  24-13: ESH date/time annotation of 1st packet";
#        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
#        push @vals, ($use_pb5) ? pb5_time($rec, \$pos) : cds_time($rec, \$pos);
#        S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));
#
#        # Item 24-14
#        spare($rec, \$pos, 1, "24-14") if ($use_pb5);
#
#        # Item 24-15
#        push @names, "  24-15: ESH date/time annotation of last packet";
#        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
#        push @vals, ($use_pb5) ? pb5_time($rec, \$pos) : cds_time($rec, \$pos);
#        S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

        # Item 24-16
        push @names, "  24-16: Packets from VCDUs corrected by R-S decoding";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals, getval($rec, \$pos, 4, "N");
        S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

        # Item 24-17
        push @names, "  24-17: Number of packets in dataset";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals, getval($rec, \$pos, 4, "N");
        S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

        # Item 24-18
        push @names, "  24-18: Number of octets in dataset";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals, getval($rec, \$pos, 8, "L");
        S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

        # Item 24-19
        spare($rec, \$pos, 8, "24-19");
    }
    # Item 25
    spare($rec, \$pos, 3, "25");
    # Item 25-1
    push @names, "25-1: Number of files in dataset";
    S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
    my $n_files = getval($rec, \$pos, 1, "C", 1, 255, "25-1");
    push @vals, $n_files;
    S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

    my @pktfiles;
    $met{'NumberOfFiles'} = $n_files;
    for ($i = 0; $i < $n_files; $i++) {
        # Item 25-2
        push @names, "  25-2: Name of PDS/EDS file";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        push @vals, getval($rec, \$pos, 40, "A40");
        S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));
        my $pktfile = (@vals)[-1];
        push @pktfiles, $pktfile;

        # Item 25-3
        spare($rec, \$pos, 3, "25-3");

        # Item 25-4
        push @names, "  25-4: Number of APIDs in file";
        S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
        my $n_apids = getval($rec, \$pos, 1, "C", 0, 100, "25-4");
        push @vals, $n_apids;
        S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

        # Need to go through the loop once for construction record file
        $n_apids = 1 if $n_apids == 0; 
        for ($j = 0; $j < $n_apids; $j++) {
            # Item 25-4.1
            spare($rec, \$pos, 1, "25-4.1");

            # Item 25-4.2
            my $scid_apid = getval($rec, \$pos, 3, "B24");
            push @names, "    25-4.2: SCID[$i]";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals,  bin2dec(substr($scid_apid, 0, 8));
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));
            push @names, "    25-4.2: APID[$i]";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, bin2dec(substr($scid_apid, 13, 11));
            S4P::logger('DEBUG', sprintf("%d\n", (@vals)[-1]));

            # Item 25-4.3
            push @names, "    25-4.3: CCSDS timecode / secondary header of 1st packet";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, cds_time($rec, \$pos);
            S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

            # Item 25-4.4
            push @names, "    25-4.4: CCSDS timecode / secondary header of last packet";
            S4P::logger('DEBUG', sprintf("%s => ", (@names)[-1]));
            push @vals, cds_time($rec, \$pos);
            S4P::logger('DEBUG', sprintf("%s\n", (@vals)[-1]));

            # Item 25-4.5
            spare($rec, \$pos, 4, "25-4.5");
        }
    }
    $met{'Filenames'} = \@pktfiles;

    my $nvals = 1 + $#vals;
    my $message;
    for (my $i = 0; $i < $nvals; $i++) {
        $message .= sprintf("%s => %s\n",$names[$i],$vals[$i]) ;
    }
    print $message if ($verbose);

    return %met;
}
##############################################################################
# General use subroutines
##############################################################################
sub getval{
    my ($data, $r_pos, $nbytes, $type, $low, $high, $name) = @_;
    if ($$r_pos >= $reclen) {
        die "Oops! walked off the end of the record!\n";
    }
    my $item = substr($data, $$r_pos, $nbytes);
    my $val = join '', unpack($type, $item);
    $$r_pos += $nbytes;
    check_val($name, $val, $low, $high) if ($name);
    return $val;
}
sub pb5_time {
    my ($data, $r_pos) = @_;
    my $item = substr($data, $$r_pos, 7);
    $$r_pos += 7;
    my $bits = unpack('B56', $item);
    my $flag = substr($bits, 0, 1);
    my $jday = bin2dec(substr ($bits, 1, 14));
    my $half_day =  3600 * 12;
    my $secs = bin2dec(substr($bits, 15, 17));
    my ($newyear, $newmonth, $newday) =

    # Compute relative to Oct 10, 1995
    # Note:  no adjustment for "noontime" jday
    S4P::TimeTools::add_delta_days(1995, 10, 10, $jday);
    # These are ignored (for now)
    my $millisecs = bin2dec(substr($bits, 32, 10));
    my $microsecs = bin2dec(substr($bits, 42, 10));
    my $hour = int($secs / 3600);
    $secs = int($secs % 3600);
    my $minute = int($secs / 60);
    $secs = int($secs % 60);
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $newyear, $newmonth, $newday, $hour, $minute, $secs);
}

sub bin2dec {
    my $bin = shift;
    my $length = length($bin);
    substr ($bin, 0,0) = '0' x (32 - $length);
    my $dec = unpack('N',pack("B32", $bin));
    return $dec;
}
sub cds_time {
    my ($rec, $r_pos) = @_;
    my @sc_time = unpack "CCCCCCCC", substr($rec, $$r_pos, 8);
    my $bits = unpack("B64", substr($rec, $$r_pos, 8));
    my $pfield_flag = substr($bits,1) ;
    my $secondary_header_id = $sc_time[0] & 128;
    my $err = 0;
    $err++ if !check_val("CCSDS Secondary Header", $secondary_header_id, 0, 0);
    $sc_time[0] %= 128;  # Should be 0, but just in case, do as much as we can
    my $days = ($sc_time[0] * 256) + $sc_time[1];
    my $millisec = (($sc_time[2]*256 + $sc_time[3]) * 256 + $sc_time[4]) * 256 + $sc_time[5];
    my $microsec = ($sc_time[6] * 256) + $sc_time[7];
    $$r_pos += 8;
    $err++ if !check_val("CCSDS Millisec", $millisec, 0, 86401 * 1000 - 1);
    $err++ if !check_val("CCSDS Microsec", $microsec, 0, 999);
    my $on_leap = ($millisec >= 86400000);
    $millisec -= 1000 if $on_leap;

    # Convert to UTC
    my @jd_utc = ((2436204.5+$days), ($millisec+$microsec/1000.)/86400000.0);
    my $day_frac_secs = $jd_utc[1] * 86400 + 0.0000005;
    my $hours = int($day_frac_secs / 3600.);

    if ($hours == 24) {
        $days++;
        $hours = 0;
    }
    my ($year, $month, $day) = calday($jd_utc[0] + 0.5);

    my $minutes = int(($day_frac_secs - $hours * 3600.) / 60.);
    my $seconds = $day_frac_secs - ($hours * 3600.) - ($minutes * 60.);
    my $int_secs = int($seconds);
    my $frac_secs = int (($day_frac_secs - int($day_frac_secs)) * 1000000);
    my $utc = sprintf("%04d-%02d-%02dT%02d:%02d:%02d.%06dZ", 
        $year, $month, $day, $hours, $minutes, $seconds, $frac_secs);
    return $err ? '' : $utc;
}
sub cuc_time {
    my $rec = shift ;
    my $pos = shift ;
    my $err = 0 ;

    my $bits = unpack("B64", $rec);
    my $pfield = bin2dec(substr($bits,0,8));
    my $leapsecs = bin2dec(substr($bits,9,7));
    my $seconds = bin2dec(substr($bits,16,32));
    my $subsecs = bin2dec(substr($bits,48,16));

    S4P::logger("DEBUG","leapsecs:$leapsecs seconds:$seconds subsecs:$subsecs\n") ;

    $seconds -= $leapsecs ;

    my $micsec = $subsecs*15625/1024 ;
    my $days = int ($seconds/86400) ;
    my $pday = $seconds - 86400 * $days ;
    $pday += $micsec/1000000 ;
    my $fday = $pday / 86400 ;
    my $time = $days + $fday ;

    #print "\tdays:$days fday:$fday time:$time\n" if ($opt_v) ;

    # Convert to UTC
    my @jd_utc = ((2436204.5+$days), $fday) ;
    my $day_frac_secs = $jd_utc[1] * 86400 + 0.0000005;
    my $hours = int($day_frac_secs / 3600.);

    if ($hours == 24) {
        $days++;
        $hours = 0;
    }
    my ($year, $month, $day) = calday($jd_utc[0] + 0.5);

    my $mins = int(($day_frac_secs - $hours * 3600.) / 60.);
    my $secs = $day_frac_secs - ($hours * 3600.) - ($mins * 60.);
    my $int_secs = int($seconds);
    my $frac_secs = int (($day_frac_secs - int($day_frac_secs)) * 1000000);
    my $utc = sprintf("%04d-%02d-%02dT%02d:%02d:%02d.%06dZ",
        $year, $month, $day, $hours, $mins, $secs, $frac_secs);
    return $err ? '' : $utc;
}
sub calday {
    use integer;
    my $jday = shift;
    my $l = $jday + 68569;
    my $n = 4 * $l / 146097;
    $l -= (146097*$n + 3)/4;
    my $year = 4000*($l + 1)/1461001;
    $l -= (1461*($year)/4 - 31);
    my $month = 80*$l/2447;
    my $day = $l - 2447 * $month/80;
    $l = $month / 11;
    $month += 2 - (12 * $l);
    $year = 100*($n - 49) + $year + $l;
    return ($year, $month, $day);
}
sub check_val {
    my ($name, $val, $low, $high) = @_;
    my $errstr;
    if ($val < $low) {
        $errstr = "ERROR: $name too low ($val < $low)\n";
    }
    if ($val > $high) {
        $errstr = "ERROR: $name too high ($val > $high)\n";
    }
    if ($errstr) {
        $main::opt_w ? warn $errstr : die $errstr;
    }
    return $errstr ? 0 : 1;
}
sub skip {
    my ($rec, $r_pos, $n_bytes, $item) = @_;
    $$r_pos += $n_bytes;
    return 1;
}
sub spare {
    my ($rec, $r_pos, $n_bytes, $item) = @_;
    my $string = substr($rec, $$r_pos, $n_bytes);
    my @bytes = unpack('C' x $n_bytes, $string);
    my $nbytes = scalar(@bytes);
    my $i;
    my $errstr;
    for ($i = 0; $i < $nbytes; $i++) {
        $errstr .= "ERROR: non-zero byte $bytes[$i] found in spares in item $item at byte $i\n" if ($bytes[$i]);
    }
    if ($errstr) {
        $main::opt_w ? warn $errstr : die $errstr;
    }
    $$r_pos += $n_bytes;
    return 1;
}
sub usage {
    die << "EOF";
Usage:  $0 [-w] [-t] -c <construction_record> 
or 
$0 [-s start_pkt] [-e end_pkt] [-v] -p <packet_file>
EOF
}

sub apid2shortname {
    my $apid = shift;
    my $pds_id = shift;
#Note that this will have to be updated for JPSS-1 - spaceraft ID will have to be taken into account
    my %shortnames = qw(
   4 AM1ANC
   0 SNPP_BusCriTlm
   1 SNPP_BusHSTlmHR
   2 SNPP_BusHSTlmLR
   6 SNPP_PUMATlm
   7 SNPP_DSEP
   8 SNPP_ADCSTlmHR
   9 SNPP_ADCSTlmLR
  11 SNPP_EphAtt
  12 SNPP_ADCSDiag1
  16 SNPP_StrTrk
  20 SNPP_ADCSDiag2
  21 SNPP_ADCSDiag
  65 SNPP_HRGyroTlm
 257 AIR10XNM
 259 AIRAACAL
 260 AIRASCAL
 261 AIR10SCC
 262 AIR10SCI
 288 AIR20XNM
 289 AIR20XSM
 290 AIR20SCI
 342 AIRH0ScE
 404 AIRB0SCI
 405 AIRB0CAL
 406 AIRB0CAH
 407 AIRB0CAP
 414 AIRH1ENC
 415 AIRH2ENC
 416 AIRH1ENG
 417 AIRH2ENG
 515 ATMS_SCIENCE_Group
 512 ATMS_HskCmdStat
 516 ATMS_DIAG_Group
 517 ATMS_DWELL_Group
 518 ATMS_Hsk
 513 ATMS_Hsk_LEOAS
 524 ATMS_DWELL_Group
 528 ATMS_SCIENCE_Group
 530 ATMS_SCIENCE_Group
 531 ATMS_SCIENCE_Group
 536 ATMS_DIAG_Group
 544 OMPS_Hsk
 545 OMPS_Hsk_LEOA
 547 OMPS_Cal
 548 OMPS_Eng
 560 OMPS_SciNadTCol
 561 OMPS_SciNadProf
 562 OMPS_LmbProfLX
 563 OMPS_LmbProfSX
 564 OMPS_SciNadTColCal
 565 OMPS_SciNadProfCal
 566 OMPS_CalLmbProf
 580 OMPS_DiagTColCal
 581 OMPS_DiagNadProfCal
 582 OMPS_DiagLmbProfCal
 546 OMPS_DiagTest
 549 OMPS_Dwell
 550 OMPS_DiagFSWBootSt
 556 OMPS_MemoryDump
 576 OMPS_DiagNadTCol
 577 OMPS_DiagNadProf
 578 OMPS_DiagLmbProfLX
 579 OMPS_DiagLmbProfSX
 957 PM1GBAD1
 958 PM1GBAD4
 959 PM1GBAD8
 967 AURGBAD1
 968 AURGBAD4
 969 AURGBAD8
1288 CrIS_Hsk_LEOAS
1289 CrIS_SCIENCE_Group
1290 CrIS_SCIENCE_Group
1291 CrIS_DWELL_Group
1292 CrIS_DWELL_Group
1293 CrIS_DWELL_Group
1294 CrIS_DIAG_Group
1295 CrIS_DIAG_Group
1296 CrIS_DIAG_Group
1397 CrIS_DWELL_Group
1398 CrIS_DIAG_Group
1616 HIR0ENG
1630 HIR0BENG
1631 HIR0BSCI
1632 HIR0SCI
1732 ML0ENG1
1734 ML0ENG2
1736 ML0ENG3
1738 ML0ENG4
1740 ML0ENG5
1742 ML0ENG6
1744 ML0SCI1
1746 ML0SCI2
1748 ML0MEM
1834 OML0ED
1836 OML0A1
1837 OML0A2
1838 OML0UV
1840 OML0V
);

    for my $i (1280 .. 1287) { $shortnames{$i} = 'CrIS_HSK_Group' ; }
    for my $i (1315 .. 1395) { $shortnames{$i} = 'CrIS_SCIENCE_Group' ; }

    my $shortname = $shortnames{$apid} ;
    if ($shortname) {
        if (($pds_id =~ /P157.................S/) and ($apid != 1288) and ($apid != 513)) { $shortname .= "S" ; }
        return $shortname;
    }
    else {
        S4P::logger('ERROR', "Cannot find ShortName for APID $apid");
        return;
    }
}
