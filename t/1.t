# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

################################################################################
# 1.t,v 1.3 2007/12/31 22:15:57 lynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

# change 'tests => 2' to 'tests => last_test_to_print';

use Test::More tests => 7;
BEGIN { use_ok('S4P') };
ok(S4P::logger('FATAL', "Fatal message (just kidding, though)"));
ok(S4P::logger('ERROR', "Error message"));
ok(S4P::logger('WARN', "Warn message"));
ok(S4P::logger('INFO', "Info message"));
ok(S4P::logger('DEBUG', "Debug message"));
ok(S4P::logger('RANDOM', "Random message"));
