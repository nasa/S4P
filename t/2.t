# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

################################################################################
# 2.t,v 1.1 2008/07/07 21:50:39 clynnes Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

# change 'tests => 2' to 'tests => last_test_to_print';

use Test::More tests => 6;
BEGIN { use_ok('S4P') };

# check_pid()
my $bad_pid = 99999999;
ok(S4P::check_pid($$), "check_pid($$)");
is(S4P::check_pid(99999999), 0, "check_pid(99999999)");

# check_job()
my $dir = "RUNNING.TEST.$$";
mkdir($dir) or die "Cannot mkdir $dir: $!";
ok(S4P::write_job_status ($dir, 'RUNNING', "DO.TEST.$$.wo", "No comment", "testuser", $bad_pid));
my ($status, $pid, $owner, $original_work_order, $comment) = S4P::check_job($dir);
is($status, "RUNNING", "Normal check_job()");
ok(S4P::job_is_defunct($dir));

# cleanup
unlink("$dir/job.status") or die ("Cannot unlink $dir/job.status: $!");
rmdir($dir) or die("Cannot rmdir $dir: $!");
