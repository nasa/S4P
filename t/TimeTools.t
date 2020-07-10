################################################################################
# TimeTools.t,v 1.2 2006/09/13 12:54:58 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use Test::More tests => 2;
BEGIN { use_ok('S4P::TimeTools') };
my $t1 = "2006-04-05T00:00:00Z";
my $t2 = "2006-04-05T00:00:00.0000Z";
my ($t3, $t4) = S4P::TimeTools::format_CCSDS_to_compare($t1, $t2);
warn "$t1 is now $t3";
is ($t3, $t4, "format_CCSDS_to_compare");
