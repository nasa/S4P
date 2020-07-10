use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
my @scripts = qw(
scripts/cpooldb.pl
scripts/dbedit.pl
scripts/dbls.pl
scripts/log_case.pl
scripts/lspooldb.pl
scripts/pcf_summary.pl
scripts/remove_job.pl
scripts/replace_mode.pl
scripts/restart_job.pl
scripts/s4pshutdown.pl
scripts/s4p_import.pl
scripts/s4p_mk_pdr.pl
scripts/s4p_pdr_fetch.pl
scripts/s4p_pooldb.pl
scripts/s4p_remote_polling_pdr.pl
scripts/s4p_repeat_work_order.pl
scripts/s4p_restart_job.pl
scripts/s4p_restart_all_jobs.pl
scripts/s4p_stat.pl
scripts/s4p_station.pl
scripts/s4pstart.ksh
scripts/s4p_start.sh
scripts/s4p_subscribe.pl
scripts/s4p_toggle.pl
scripts/s4p_token.pl
scripts/s4p_zk.pl
scripts/send_downstream.pl
scripts/sim.pl
scripts/station_control.pl
scripts/stationmaster.pl
scripts/stop_station.pl
scripts/tkargus.pl
scripts/tkexec.pl
scripts/tkjob.pl
scripts/tkstat.pl
scripts/xml2odl.pl
);
WriteMakefile(
    'NAME'		=> 'S4P',
    'EXE_FILES'		=> \@scripts,
    'VERSION'		=> '5.28.5',
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      ( AUTHOR     => 'GES DISC') : ()),
);
sub MY::perm_rwx{ return '775'}
sub MY::perm_rw{ return '664'}
