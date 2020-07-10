# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

################################################################################
# PDR.t,v 1.4 2006/12/29 17:49:24 lynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 12; 
use Sys::Hostname;
use strict;
BEGIN { use_ok('S4P::PDR') };
BEGIN { use_ok('S4P::FileGroup') };

write_pdr();
test_bad_pdr(bad_pdr1());
test_bad_pdr(bad_pdr2());

#########################

sub write_pdr {
    my $scifi = "test.hdf";
    my $met = "$scifi.met";
    my $pdr_file = "test.pdr";
    my $dir = $ENV{'TMPDIR'} || '/var/tmp';
    $dir = '.' if (! -d $dir);
    my (@files, $fg, $pdr, $pdr_text);
    push @files, write_file("$dir/$scifi", "Hello, world\n");
    push @files, write_file("$dir/$met", "Metadata for $scifi");
    my $hostname = Sys::Hostname::hostname();
    ok( $pdr = S4P::PDR::start_pdr() );
    ok($fg = $pdr->add_granule(
           'node_name' => $hostname, 
           'data_type' => 'TEST', 
           'data_version' => 1, 
           'files' => \@files));
    ok($pdr_text = $pdr->sprint());
    like($pdr_text, qr/FILE_ID=$scifi/);
    ok($pdr_text = $pdr->sprint(1));
    like($pdr_text, qr/FILE_ID = $scifi/);
    $pdr->write_pdr($pdr_file);
    ok(-f $pdr_file);
    # Make sure it is parseable
    ok(S4P::PDR::read_pdr($pdr_file));
    unlink($pdr_file, @files);
#    print STDERR $pdr_text;
}

sub write_file {
    my ($path, $text) = @_;
    open F, ">$path" or die "Cannot write to $path: $!";
    print F $text;
    close F;
    return $path;
}
sub test_bad_pdr {
    my $text = shift;
    my $dir = $ENV{'TMPDIR'} || '/var/tmp';
    $dir = '.' if (! -d $dir);
    my $file = "$dir/bad1.pdr";
    open BAD_PDR, ">$file" or die "Cannot write to $file: $!";
    print BAD_PDR $text;
    close(BAD_PDR);
    my $pdr = S4P::PDR::read_pdr($file);
    ok (! $pdr);
    unlink($file);
}
sub bad_pdr1 {
    return << 'EOF';
ORIGINATING_SYSTEM = ODPS;
TOTAL_FILE_COUNT = 2;
EXPIRATION_TIME = 2006-12-11T10:44:45Z;

OBJECT = FILE_GROUP;
OBJECT = FILE_GROUP;
    DATA_TYPE = OMO3PR;
    NODE_NAME = 145.23.254.158;
    OBJECT = FILE_SPEC;
        DIRECTORY_ID = /data/omi/gdaac/test/outgoing/OMPROO3;
        FILE_ID = OMI-Aura_L2-OMO3PR_2006m1203t2118-o12693_v002-2006m1206t062642.he5;
        FILE_TYPE = HDF-EOS;
        FILE_SIZE = 13156494;
        FILE_CKSUM_TYPE = MD5;
        FILE_CKSUM_VALUE = a070845f731399cb88c3ab723801d2ba;
    END_OBJECT = FILE_SPEC;
    OBJECT = FILE_SPEC;
        DIRECTORY_ID = /data/omi/gdaac/test/outgoing/OMPROO3;
        FILE_ID = OMI-Aura_L2-OMO3PR_2006m1203t2118-o12693_v002-2006m1206t062642.he5.met;
        FILE_TYPE = METADATA;
        FILE_SIZE = 19214;
        FILE_CKSUM_TYPE = MD5;
        FILE_CKSUM_VALUE = dd2b36440611017a4a2618a0fce21ca6;
    END_OBJECT = FILE_SPEC;
END_OBJECT = FILE_GROUP;
EOF
}
sub bad_pdr2 {
    return << 'EOF';
ORIGINATING_SYSTEM = ODPS;
TOTAL_FILE_COUNT = 2;
EXPIRATION_TIME = 2006-12-11T10:44:45Z;

OBJECT = FILE_GROUP;
    DATA_TYPE = OMO3PR;
    NODE_NAME = 145.23.254.158;
    OBJECT = FILE_SPEC;
        DIRECTORY_ID = /data/omi/gdaac/test/outgoing/OMPROO3;
        FILE_ID = OMI-Aura_L2-OMO3PR_2006m1203t2118-o12693_v002-2006m1206t062642.he5;
        FILE_TYPE = HDF-EOS;
        FILE_SIZE = 13156494;
        FILE_CKSUM_TYPE = MD5;
        FILE_CKSUM_VALUE = a070845f731399cb88c3ab723801d2ba;
    END_OBJECT = FILE_SPEC;
    OBJECT = FILE_SPEC;
        DIRECTORY_ID = /data/omi/gdaac/test/outgoing/OMPROO3;
        FILE_ID = OMI-Aura_L2-OMO3PR_2006m1203t2118-o12693_v002-2006m1206t062642.he5.met;
        FILE_TYPE = METADATA;
        FILE_SIZE = 19214;
        FILE_CKSUM_TYPE = MD5;
        FILE_CKSUM_VALUE = dd2b36440611017a4a2618a0fce21ca6;
    END_OBJECT = FILE_SPEC;
OBJECT = FILE_GROUP;
    DATA_TYPE = OMO3PR;
    NODE_NAME = 145.23.254.158;
    OBJECT = FILE_SPEC;
        DIRECTORY_ID = /data/omi/gdaac/test/outgoing/OMPROO3;
        FILE_ID = OMI-Aura_L2-OMO3PR_2006m1203t2118-o12693_v002-2006m1206t062642.he5;
        FILE_TYPE = HDF-EOS;
        FILE_SIZE = 13156494;
        FILE_CKSUM_TYPE = MD5;
        FILE_CKSUM_VALUE = a070845f731399cb88c3ab723801d2ba;
    END_OBJECT = FILE_SPEC;
    OBJECT = FILE_SPEC;
        DIRECTORY_ID = /data/omi/gdaac/test/outgoing/OMPROO3;
        FILE_ID = OMI-Aura_L2-OMO3PR_2006m1203t2118-o12693_v002-2006m1206t062642.he5.met;
        FILE_TYPE = METADATA;
        FILE_SIZE = 19214;
        FILE_CKSUM_TYPE = MD5;
        FILE_CKSUM_VALUE = dd2b36440611017a4a2618a0fce21ca6;
    END_OBJECT = FILE_SPEC;
END_OBJECT = FILE_GROUP;
EOF
}
