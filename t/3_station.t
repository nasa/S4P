use FindBin qw($Bin);
use S4P::Station;
use File::Basename;
use strict;
use Test::More tests => 19;

BEGIN { use_ok('S4P::Station') };                ### Test
BEGIN { use_ok('S4P::Job') };                ### Test

my $dir = $Bin;
chdir $dir or die "Cannot chdir $dir: $!";
my $sta = new S4P::Station('config_file' => 'station_01.cfg');
isa_ok($sta, 'S4P::Station');                    ### Test
is($sta->polling_interval, 5);                   ### Test
$sta->polling_interval(2);
is($sta->polling_interval, 2);                   ### Test

is($sta->commands->{'TEST1'}, 'sleep 1 && echo');### Test
is($sta->virtual_jobs->{'TEST1'}, 1);            ### Test
# $sta->startup();
$sta->max_children(0);
is($sta->max_children, 0, "Max children = 0");   ### Test

# Sorting
my @job_list = qw(DO.CHARLIE.1.wo DO.DELTA.1.wo DO.ALPHA.1.wo DO.BETA.1.wo);
# Default is alphabetical
my @sort = $sta->sort_job_list(@job_list);
is($sort[0], 'DO.ALPHA.1.wo');                   ### Test
is($sort[1], 'DO.BETA.1.wo');                    ### Test
is($sort[2], 'DO.CHARLIE.1.wo');                 ### Test

$sta->sort_jobs(['BETA', 'CHARLIE', 'ALPHA', 'DELTA']);
@sort = $sta->sort_job_list(@job_list);
is($sort[0], 'DO.BETA.1.wo');                    ### Test
is($sort[1], 'DO.CHARLIE.1.wo');                 ### Test
is($sort[2], 'DO.ALPHA.1.wo');                   ### Test

# Do some testing of Job object
my $job = new S4P::Job('station' => $sta, 
  'work_order' => 'DO.TEST1.RXPAN_FIRST_TEST_STRING_EZ.SimAlg1_2005292172500.wo');
isa_ok($job, 'S4P::Job');                    ### Test
is($job->type, 'TEST1');
is($job->id, 'RXPAN_FIRST_TEST_STRING_EZ.SimAlg1_2005292172500');

# Take it out for a spin
ok($sta->startup, "Station startup");            ### Test
# Polling should generate one virtual job
my @jobs = $sta->poll;
ok(@jobs, "Polling");                            ### Test

######### Clean up
my @debris = qw(station.log station_counter.log station.pid station.lock);
unlink @debris;
unlink @jobs;

exit(0);
