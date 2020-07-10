#!/usr/bin/perl

=head1 NAME

s4p_remote_polling_pdr.pl - script to poll a remote directory for PDRs

=head1 SYNOPSIS

s4p_remote_polling_pdr.pl
[B<-h>]
[B<-f> I<configuration file>]

OR

[B<-r> I<remote_host>]
[B<-p> I<remote_directory>]
[B<-d> I<local_directory>]
[B<-o> I<history_file>]
[B<-t> I<protocol: FTP or SFTP>]
[B<-e> I<PDR name pattern>]
I<workorder>

=head1 ARGUMENTS

=over

=item B<-h> 

Prints out synopsis.

=item B<-f> I<configuration file>

File containing parameters for polling: cfg_history_file, cfg_remote_host, 
cfg_remote_dir, cfg_local_dir, cfg_CFG::cfg_protocol, cfg_pdr_pattern, 
cfg_data_version. Command line options, if specified, will over ride these 
values. 

=item B<-r> I<remote_hostanme>

Hostname to ftp to in order to poll. A suitable entry in the .netrc file must 
exist for this host. (=cfg_remote_host in config file)

=item B<-p> I<remote_directory>

Directory on the remote host (as seen in the ftp session) which will be 
examined for new PDRs. (=cfg_remote_dir in config file)

=item B<-d> I<local_directory>

Local directory to which new PDRs will be directed.
(=cfg_local_dir in config file)

=item B<-o> I<history_file>

Local filename containing list of previously encountered PDRs.  Name defaults 
to "../oldlist.txt". (cfg_history_file in config file)

=item B<-t> I<protocol>

Specifies the protocol to be used for polling. Valids are FTP and SFTP. 
(=cfg_protocol in config file)

=item B<-e> I<PDR name pattern>

Optional argument which specifies filename pattern (default is \.PDR$)
(=cfg_pdr_pattern in config file)

=head1 DESCRIPTION

=head1 AUTHOR

Mike Theobald, NASA/GSFC, Code 902, Greenbelt, MD  20771.
T. Dorman, SSAI, NASA/GSFC, Greenbelt, MD 20771
M. Hegde, SSAI, NASA/GSFC, Greenbelt, MD 20771

=cut

###############################################################################
# s4p_remote_polling_pdr.pl,v 1.4 2019/05/06 15:48:47 glei Exp
# -@@@ S4P, Version Release-5_28_5
###############################################################################

use strict;
use Safe;
use Net::FTP;
use Net::Netrc;
use Getopt::Std;
use File::Basename;
use File::Copy;
use S4P;
use S4P::PDR;

use vars qw($opt_h $opt_f $opt_r $opt_p $opt_d $opt_o $opt_t $opt_e );

#Read and parse command line options
getopts( 'f:r:p:d:o:t:e:h' );

S4P::perish( 1, "Use: $0 -f <config file>\n or"
    . " $0 -o <history file> -r <remote host> -p <remote dir> -d"
    . " <local dir> -t <protocol> -e <PDR pattern>" ) if $opt_h;
if ( $opt_f ) {
    # Read the configuration file if specified
    my $cpt = new Safe 'CFG';
    $cpt->share( '$cfg_history_file', '$cfg_remote_host', '$cfg_remote_dir',
        '$cfg_local_dir', '$cfg_protocol', '$cfg_pdr_pattern',
        '%cfg_data_version' );
    $cpt->rdo($opt_f) or 
        S4P::perish(1, "Cannot read config file $opt_f in safe mode: ($!)");
}

# Command line options over ride the definitions in configuration file
$CFG::cfg_history_file = $opt_o if defined $opt_o;
$CFG::cfg_remote_host = $opt_r if defined $opt_r;
$CFG::cfg_remote_dir = $opt_p if defined $opt_p;
$CFG::cfg_local_dir = $opt_d if defined $opt_d;
$CFG::cfg_protocol = $opt_t if defined $opt_t;
$CFG::cfg_pdr_pattern = $opt_e if defined $opt_e;

S4P::perish( 1, "Specify history file (-o)" )
    unless defined $CFG::cfg_history_file;
S4P::perish( 1, "Specify host to be polled (-r)" )
    unless defined $CFG::cfg_remote_host;
S4P::perish( 1, "Specify directory to be polled (-p)" )
    unless defined $CFG::cfg_remote_dir;
S4P::perish( 1, "Specify local directory for downloading PDR (-d)" )
    unless defined $CFG::cfg_local_dir;
S4P::perish( 1, "Specify protocol (-t)" )
    unless defined $CFG::cfg_protocol;
$CFG::cfg_pdr_pattern = '\.PDR$' unless defined $CFG::cfg_pdr_pattern;
$CFG::cfg_local_dir .="/" unless ( $CFG::cfg_local_dir =~ /\/$/ );
    
# A hash to keep track of downloaded PDRs
my %oldlist;

# Lock a dummy file to lock out access old list file.
open( LOCKFH, ">$CFG::cfg_history_file.lock" )
    || S4P::perish( 1, "Failed to open lock file" );
unless( flock( LOCKFH, 2 ) ) {
    close( LOCKFH );
    S4P::perish( 1, "Failed to get a lock" );
}

# Read oldlist (%oldlist hash in external file of remote PDRs already processed)
open ( OLDLIST,"$CFG::cfg_history_file" ) 
    || S4P::logger( "WARN",
	"Failed to open oldlist file $CFG::cfg_history_file; created one" );

while ( <OLDLIST> ) {
    chomp() ;
    $oldlist{$_} = "old";
}
close(OLDLIST);
 
# Transfer status
my $xferstatus = 0;
if ( $CFG::cfg_protocol eq 'FTP' ) {
    # specify default firewall type
    my $firewallType = $ENV{FTP_FIREWALL_TYPE} ? $ENV{FTP_FIREWALL_TYPE} : 1;

    # Open FTP connection, login, cd to polldir and ls contents.
    my $ftp;
    if ( $ENV{FTP_FIREWALL} ) {
        # Create an Net::FTP object with Firewall option
        my $firewall = $ENV{FTP_FIREWALL};
        $ftp = Net::FTP->new( $CFG::cfg_remote_host, Firewall => $firewall, 
		FirewallType => $firewallType );
    } else {
        # No firewall specified, let .libnetrc resolve if firewall is required
        $ftp = Net::FTP->new( $CFG::cfg_remote_host );
    }

    S4P::perish( 1, "Failed to create an FTP object for $CFG::cfg_remote_host" )
        unless defined $ftp;
    S4P::perish( 1,
	"Failed to login to $CFG::cfg_remote_host (" . $ftp->message() . ")" ) 
        unless $ftp->login();
    S4P::logger( "INFO",
	"Beginning scan of $CFG::cfg_remote_host:$CFG::cfg_remote_dir" );
    my @remfiles;
    if ( $ftp->cwd( $CFG::cfg_remote_dir ) ) {
        @remfiles = $ftp->ls();
    } else {
        S4P::logger( "ERROR",
                     "Failed to change directory to $CFG::cfg_remote_dir ("
                     . $ftp->message() . ")" );
    }    
    S4P::logger( "INFO", @remfiles . " files found in $CFG::cfg_remote_dir" );

    # Check contents against oldlist, transfer any new, and update oldlist
    foreach my $remfile ( @remfiles ) {
        next unless ( $remfile =~ m/$CFG::cfg_pdr_pattern/ );
        S4P::logger( "INFO", "$remfile is old: skipping" )
            && next if ( $oldlist{$remfile} eq 'old' );
    
	# Transfer files to local directory
        if ( $ftp->get( $remfile ) ) {
	    $oldlist{$remfile} = 'new';
	} else {
            S4P::logger( "ERROR",
                "Failure in transfer of $remfile (" . $ftp->message . ")"  );
        }
    }
    # Gracefully, close session.
    $ftp->quit() if ( ref( $ftp ) eq 'Net::FTP' );
} elsif ( $CFG::cfg_protocol eq 'SFTP' ) {
    # Lookup hostname in .netrc to find login name.
    my $machine = Net::Netrc->lookup( $CFG::cfg_remote_host )
        || S4P::perish( 1, "Failed to lookup $CFG::cfg_remote_host in .netrc" );
    my $login = $machine->login()
        || S4P::perish( 1,
            "Failed to find login name for $CFG::cfg_remote_host in .netrc" );
    my $passwd = ( defined $login ) ? ( $machine->password() ) : undef;

    # construct sftp batch 'ls' command file
    my $sftpBatchFile = "s4pa_sftp.cmd";
    if ( open ( BATCH, "> $sftpBatchFile" ) ) {
	print BATCH "cd $CFG::cfg_remote_dir\nls -1\nquit\n";
	close ( BATCH );
    } else {
        S4P::perish( 1,
	    "Failed to write to SFTP batch file, $sftpBatchFile ($!)" );
    }

    # execute sftp through system call for PDR listing
    my $sftpLogFile = "s4pa_sftp.log";
    my $sftpCmd = "sftp -b $sftpBatchFile $login\@$CFG::cfg_remote_host"
	. " > $sftpLogFile 2>&1";
    my $sftpStatus = system( $sftpCmd );
    unlink ( $sftpBatchFile );
    if ( $sftpStatus >>= 8 ) {
	S4P::perish( 1,
	    "PDR polling by sftp to $CFG::cfg_remote_host:$CFG::cfg_remote_dir"
	    . " failed (exit=$sftpStatus)" );
	unlink ( $sftpLogFile );
    } else {
	# Create a new batch file for writing "get" commands
	if ( open ( BATCH, ">$sftpBatchFile" ) ) {
	    # Open the log file created from sftp "ls" commands above
	    if ( open ( LOG, "<$sftpLogFile" ) ) {
		while ( <LOG> ) {
		    chomp();
		    my $remfile = $_;
		    # Skip hidden files.
		    next if ( $remfile =~ /^\./ );
		    # Skip non- $pattern extension file (default .PDR)
		    next unless ( $remfile =~ m/$CFG::cfg_pdr_pattern/ );
		    S4P::logger( "INFO", "$remfile is old: skipping" )
			&& next if ( $oldlist{$remfile} eq 'old' );
		    S4P::logger( "INFO", "Found new PDR: $remfile" );
		    # store new PDR in the sftp get command file
		    print BATCH "get $CFG::cfg_remote_dir/" . "$remfile\n";
                    $oldlist{basename($remfile)} = "new";
		}
		close ( LOG );
	    } else {
		S4P::logger( "WARNING",
		    "Failed to open $sftpLogFile for reading ($!)" );
	    }
	    unlink ( $sftpLogFile );
	    print BATCH "quit\n";
	    close ( BATCH );
	} else {
	    unlink( $sftpLogFile );
	    S4P::perish( 1, "Failed to open SFTP batch file, $sftpBatchFile,"
		. " for getting files ($!)" );
	}

	# execute sftp through system call for PDR polling
	$sftpStatus = system( $sftpCmd );
	unlink ( $sftpBatchFile );
        unlink ( $sftpLogFile );
	if ( $sftpStatus >>= 8 ) {
            unlink ( $sftpLogFile );
	    S4P::logger( "ERROR", "PDR polling of $CFG::cfg_remote_host:"
		. " $CFG::cfg_remote_dir by SFTP failed (exit: $sftpStatus" );
	}
    }
} elsif ( $CFG::cfg_protocol eq 'FILE' ) {
    $CFG::cfg_remote_dir .= '/' unless ( $CFG::cfg_remote_dir =~ /\/$/ );
    my @remfiles = glob( "$CFG::cfg_remote_dir*" );

    foreach my $remfile ( @remfiles ) {
        my $pdr = basename($remfile); 
        next unless ( $pdr =~ m/$CFG::cfg_pdr_pattern/ );
        S4P::logger( "INFO", "$pdr is old: skipping" )
            && next if ( $oldlist{$pdr} eq 'old' );
        my $localfile = "./$pdr";
        if ( File::Copy::copy( $remfile, $localfile ) ) {
            S4P::logger( "INFO", "Success in copy of $remfile" );
            $oldlist{$pdr} = "new";
        } else {
            S4P::logger ( "ERROR", "Failure to copy " . $remfile
                         . " to $CFG::cfg_local_dir" );
        }
    }
}

# Create new oldlist
open ( OLDLIST, ">>$CFG::cfg_history_file" )
    || S4P::perish( 1,
	"Failed open history file $CFG::cfg_history_file for writing ($!)" );
foreach my $remfile ( sort keys( %oldlist ) ) {
   next if ( $oldlist{$remfile} eq "old" );
   # If successful in transfering file, move the file to local 
   # directory and make the file writable. Save the file name in 
   # history.
   my $pdrName = basename( $remfile );
   my $pdr = S4P::PDR::read_pdr( $pdrName );
   unless ( $pdr ) {
       S4P::logger( "ERROR", "$pdrName is invalid; $S4P::PDR::errstr" );
       next;
   }
   # Check whether the data type and version are supported
   my $supportedDataType = 1;
   if ( %CFG::cfg_data_version ) {
       foreach my $fileGroup ( @{$pdr->file_groups()} ) {
	   my $dataType = $fileGroup->data_type();
	   my $dataVersion = $fileGroup->data_version();
	   if ( defined $CFG::cfg_data_version{$dataType} ) {
	       $supportedDataType = 0 
		   unless ( $CFG::cfg_data_version{$dataType}{$dataVersion}
		       || $CFG::cfg_data_version{$dataType}{''} );
	   } else {
	       $supportedDataType = 0;
	       S4P::logger( "WARNING", "Data type=$dataType,"
                . " Data version=$dataVersion is unsupported" );
	   }
       }
   } 

   if ( $supportedDataType ) {
       if ( move( $pdrName, $CFG::cfg_local_dir ) ) {
	   chmod( 0644, "$CFG::cfg_local_dir/$remfile" );
	   print OLDLIST "$remfile\n" ;
       } else {
	   S4P::logger( "ERROR", "Failure to move $pdrName to"
	       . " $CFG::cfg_local_dir ($!); removing file" );
	   unlink ( $pdrName );
       }
   } else {
       print OLDLIST "$remfile\n" ;
       S4P::logger( "ERROR",
	   "$pdrName has unsupported data type/version; skipping" );
       unlink( $pdrName );
   }
}
close( OLDLIST );

# Remove lock
close( LOCKFH );
flock( LOCKFH, 8 );
exit( 0 );
