=pod
=head1 NAME

S4P::Connection - provides remote conneciton functions and access to
connection parameters.

=head1 SYNOPSIS

  use S4P::Connection;
  $connection = S4P::Connection->new( %connectionParam );
  $errorFlag = $connection->onError();
  $errorMessage = $connection->errorMessage();
  $status = $connection->setHost($host);
  $status = $connection->setProtocol($protocol);
  $status = $connection->setLogin($login);
  $status = $connection->setFirewall($firewall);
  $status = $connection->setFirewalltype($firewallType);
  $status = $connection->setParam(%params);
  ($status, log) = $connection->get($remoteFile);
  ($status, log) = $connection->put($localFiles, $remoteDir);
  ($status, log) = $connection->mget(@remoteFiles);
  ($status, log) = $connection->mput(@localFiles, $remoteDir);
  @list = $connection->ls($remoteDir);

=head1 DESCRIPTION

S4P::Connection provides methods to perform common remote connection functions.
It provides access connection parameters such as protocol, host, and login info.

=head1 AUTHOR

F. Fang

=head1 METHODS

=cut

# Connection.pm,v 1.1 2008/03/21 19:29:46 ffang Exp
# -@@@ S4PA, Version Release-5_28_5

package S4P::Connection;

use strict;
use S4P;
use Net::Netrc;
use File::Copy;
use File::Basename;
use vars '$AUTOLOAD';

################################################################################

=head2 Constructor

Description:
    Constructs the object from a connection hash.

Input:
    A hash containing connection parameters. 

Output:
    Returns S4P::Connection object.

Author:
    F. Fang
    
=cut

sub new
{
    my ( $class, %arg ) = @_;

    my $connection = {};

    if ( defined $arg{PROTOCOL} ) {
        $connection->{__PROTOCOL} = $arg{PROTOCOL};
    } else {
        $connection->{__ERROR} = 1;
        $connection->{__MESSAGE} = "Protocol not initialized";
    }
    if ( defined $arg{HOST} ) {
        $connection->{__HOST} = $arg{HOST};
    } else {
        $connection->{__ERROR} = 1;
        $connection->{__MESSAGE} = "Host not initialized";
    }
    if ( defined $arg{LOGIN} ) {
        $connection->{__LOGIN} = $arg{LOGIN};
    } else {
        $connection->{__ERROR} = 1;
        $connection->{__MESSAGE} = "Login not initialized";
    }
    if ( defined $arg{FIREWALL} ) {
        $connection->{__FIREWALL} = $arg{FIREWALL};
    }
    if ( defined $arg{FIREWALLTYPE} ) {
        $connection->{__FIREWALLTYPE} = $arg{FIREWALLTYPE};
    }

    return bless( $connection, $class );
}
################################################################################

=head2 onError

Description:
    Returns a boolean indicating whether any error flag has been raised.
    
Input:
    None.
    
Output:
    1/0 => error flag raised or not.
    
Author:
    M. Hegde
    
=cut

sub onError
{
    my ( $self ) = @_;    
    return ( defined $self->{__ERROR} ? 1 : 0 );
}

################################################################################

=head2 errorMessage

Description:
    Returns the error message
    
Input:
    None.
    
Output:
    Returns the error message if one exists.
    
Author:
    M. Hegde
    
=cut

sub errorMessage
{
    my ( $self ) = @_;    
    return ( $self->onError() ? $self->{__MESSAGE} : undef );
}

################################################################################
=head2 setHost

Description:
    Sets the hostname of a Connection object.

Input:
    Hostname string.

Output:
    Return 0/1 => failure/success

Author:
    F. Fang

=cut

sub setHost
{
    my ( $self, $hostName ) = @_;
    $self->{__HOST} = $hostName;
    return 1 if ($self->{__HOST} eq $hostName);
    return 0;
}

################################################################################
=head2 setProtocol

Description:
    Sets the protocol of a Connection object.

Input:
    Protocol string.

Output:
    Returns 0/1 => failure/success

Author:
    F. Fang

=cut
sub setProtocol
{
    my ( $self, $protocol ) = @_;
    $self->{__PROTOCOL} = $protocol;
    return 1 if ($self->{__PROTOCOL} eq $protocol);
    return 0;
}

################################################################################
=head2 setLogin

Description:
    Sets the login username of a Connection object.

Input:
    Login username string.

Output:
    Returns 1 on success and 0 on failure.

Author:
    F. Fang

=cut

sub setLogin
{
    my ( $self, $login ) = @_;
    $self->{__LOGIN} = $login;
    return 1 if ($self->{__LOGIN} eq $login);
    return 0;
}

################################################################################
=head2 setFirewall

Description:
    Sets the firewall of a Connection object.

Input:
    Firewall string.

Output:
    Returns 1 on success and 0 on failure.

Author:
    F. Fang

=cut

sub setFirewall
{
    my ( $self, $firewall ) = @_;
    $self->{__FIREWALL} = $firewall;
    return 1 if ($self->{__FIREWALL} eq $firewall);
    return 0;
}
################################################################################
=head2 setFirewallType

Description:
    Sets the firewall type of a Connection object.

Input:
    Firewall-type string.

Output:
    Returns 1 on success and 0 on failure.

Author:
    F. Fang

=cut

sub setFirewallType
{
    my ( $self, $firewallType ) = @_;
    $self->{__FIREWALLTYPE} = $firewallType;
    return 1 if ($self->{__FIREWALLTYPE} eq $firewallType);
    return 0;
}
################################################################################
=head2 setParam

Description:
    Sets the parameters of a Connection object.

Input:
    Hash of connection parameters.

Output:
    Returns 1 on success and 0 on failure.

Author:
    F. Fang

=cut

sub setParam
{
    my ( $self, %params ) = @_;
    $self = \%params;
    return 1;
}

################################################################################

=head2 get

Description:
    Carries out connection and get a file.

Input:
    A file path name.

Output:
    Status (1 on success and 0 on failure) and a log file from connection session.

Author:
    F. Fang

=cut

sub get
{
    my ( $self, $filePath ) = @_;

    my $logFile;
    my $status = 0;
    my $host;
    if (defined $self->{__HOST}) {
        $host = $self->{__HOST};
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection host is undefined";
        return (0, undef);
    }

    my $login;
    if (defined $self->{__LOGIN}) {
        $login = $self->{__LOGIN};
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection login is undefined";
        return (0, undef);
    }

    if (!$filePath) {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Remote file path name is not defined";
        return (0, undef);
    }

    if ($self->{__PROTOCOL} eq 'BBFTP') {
        $logFile = 'bbftp.log';
        my $dir = dirname $filePath;
        $dir = "." if (!$dir);
        my $file = basename $filePath;
        my $bbftpCmd = "bbftp -e \'cd $dir; get $file\'"
                     . " -E \'bbftpd -e 40000:41000\' -u $login $host";
        my $bbftpStatus = system( $bbftpCmd . " > $logFile 2>&1" );
        if (!$bbftpStatus) {
            $status = 1;
        }
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection protocol is not supported";
    }
    return ($status, $logFile);
}
################################################################################

=head2 put

Description:
    Carries out connection and put a file.

Input:
    A remote directory and a file path name.

Output:
    Status (1 on success and 0 on failure) and a log file from connection session.

Author:
    F. Fang

=cut

sub put
{
    my ( $self, $remoteDir, $filePath ) = @_;

    my $logFile;
    my $status = 0;
    my $host;
    if (defined $self->{__HOST}) {
        $host = $self->{__HOST};
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection host is undefined";
        return (0, undef);
    }

    my $login;
    if (defined $self->{__LOGIN}) {
        $login = $self->{__LOGIN};
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection login is undefined";
        return (0, undef);
    }

    if (!$filePath) {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "File to put is not defined";
        return (0, undef);
    }

    if ($self->{__PROTOCOL} eq 'BBFTP') {
        $logFile = 'bbftp.log';
        my $bbftpCmd = "bbftp -e \'put $filePath $remoteDir/\'"
                     . " -E \'bbftpd -e 40000:41000\' -u $login $host";
        my $bbftpStatus = system( $bbftpCmd . " > $logFile 2>&1" );
        if (!$bbftpStatus) {
            $status = 1;
        }
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection protocol is not supported";
    }
    return ($status, $logFile);
}

################################################################################

=head2 mget

Description:
    Carries out connection and get a list of files using a control (batch) file.

Input:
    a list of path names of files.

Output:
    Status (1 on success and 0 on failure) and a log file from connection session.

Author:
    F. Fang

=cut

sub mget
{
    my ( $self, @list ) = @_;

    my $logFile;
    my $status = 0;
    my $host;
    if (defined $self->{__HOST}) {
        $host = $self->{__HOST};
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection host is undefined";
        return (0, undef);
    }

    my $login;
    if (defined $self->{__LOGIN}) {
        $login = $self->{__LOGIN};
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection login is undefined";
        return (0, undef);
    }

    if (!@list) {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "List to get is empty";
        return (0, undef);
    }

    if ($self->{__PROTOCOL} eq 'BBFTP') {
        my $batchFile = "ctrfile";
        $logFile = $batchFile . ".res";
        if ( open ( BATCH, ">$batchFile" ) ) {
            foreach my $filePath (@list) {
                my $dir = dirname $filePath;
                my $file = basename $filePath;
                if (!$file) {
                    $self->{__ERROR} = 1;
                    $self->{__MESSAGE} = "file name empty";
                    next;
                } else {
                    print BATCH "cd $dir\n";
                    print BATCH "get $file\n";
                }
            }
            close ( BATCH );
        } else {
            $self->{__ERROR} = 1;
            $self->{__MESSAGE} = "Failed to open batch file for writing";
        }

        my $bbftpCmd = "bbftp -i \'$batchFile\' -E \'bbftpd -e 40000:41000\'"
                     . " -u $login $host > $logFile 2>&1";
        my $bbftpStatus = system( $bbftpCmd );
        if (!$bbftpStatus) {
            $status = 1;
        }
        unlink ( $batchFile );
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection protocol is not supported";
    }
    return ($status, $logFile);
}
################################################################################

=head2 mput

Description:
    Carries out connection and put a list of files using a control (batch) file.

Input:
    A remote directory and a list of path names of files.

Output:
    Status (1 on success and 0 on failure) and a log file from connection session.

Author:
    F. Fang

=cut

sub mput
{
    my ( $self, $remoteDir, @list ) = @_;

    my $logFile;
    my $status = 0;
    my $host;
    if (defined $self->{__HOST}) {
        $host = $self->{__HOST};
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection host is undefined";
        return (0, undef);
    }

    my $login;
    if (defined $self->{__LOGIN}) {
        $login = $self->{__LOGIN};
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection login is undefined";
        return (0, undef);
    }

    if (!@list) {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "List to put is empty";
        return (0, undef);
    }

    if ($self->{__PROTOCOL} eq 'BBFTP') {
        my $batchFile = "ctrfile";
        $logFile = $batchFile . ".res";
        if ( open ( BATCH, ">$batchFile" ) ) {
            foreach my $filePath (@list) {
                my $dir = dirname $filePath;
                $dir = "." if (!$dir);
                my $file = basename $filePath;
                if (!$file) {
                    $self->{__ERROR} = 1;
                    $self->{__MESSAGE} = "file name empty";
                    next;
                } else {
                    print BATCH "lcd $dir\n";
                    print BATCH "cd $remoteDir\n";
                    print BATCH "put $file\n";
                }
            }
            close ( BATCH );
        } else {
            $self->{__ERROR} = 1;
            $self->{__MESSAGE} = "Failed to open batch file for writing";
        }
        my $bbftpCmd = "bbftp -i $batchFile -E \'bbftpd -e 40000:41000\'"
                     . " -u $login $host";
        my $bbftpStatus = system( $bbftpCmd );
        if (!$bbftpStatus) {
            $status = 1;
        }
        unlink ( $batchFile );
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection protocol is not supported";
    }
    return ($status, $logFile);
}

################################################################################

=head2 ls

Description:
    Get a list of items in a remote directory.

Input:
    Remote directory.

Output:
    Status (1 on success and 0 on failure) of connection session and a file
    containing a list of items in the remote directory.

Author:
    F. Fang

=cut

sub ls
{
    my ( $self, $dir ) = @_;

    my @list = ();
    my $status = 0;
    my $host;
    if (defined $self->{__HOST}) {
        $host = $self->{__HOST};
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection host is undefined";
        return (0, undef);
    }

    my $login;
    if (defined $self->{__LOGIN}) {
        $login = $self->{__LOGIN};
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection login is undefined";
        return (0, undef);
    }
  
    if ($self->{__PROTOCOL} eq 'BBFTP') {
        my $bbftpLog = "bbftp.log";
        my $bbftpCmd = "bbftp -e \'dir $dir\' -E 'bbftpd -e 40000:41000'"
                     . " -m -u $login $host > $bbftpLog ";
        my $bbftpStatus = system( "$bbftpCmd" );
        if (!$bbftpStatus) {
            if ( open ( LOG, "<$bbftpLog" ) ) {
                while ( <LOG> ) {
                    chomp();
                    next if (/^dir/);
                    my ($junk, $df, $item) = split /\s+/;
                    push @list, $item;
                }
                $status = 1;
                close ( LOG );
            } else {
                $self->{__ERROR} = 1;
                $self->{__MESSAGE} = "Failed to open $bbftpLog for reading";
            }
        }
        unlink ( $bbftpLog );
    } else {
        $self->{__ERROR} = 1;
        $self->{__MESSAGE} = "Connection protocol is not supported";
    }
    return ($status, @list);
}


################################################################################

=head2 Accessor Methods

Description:
    Has accessor methods for S4P::Connection.
    getHost(): returns the host name.
    getProtocol(): returns the protocol name.
    getLogin(): returns the login name
    getParam(): returns parameter hash reference.

Input:
    Depends on the function.

Output:
    Depends on the function.

Author:
    F. Fang

=cut

sub AUTOLOAD
{
    my ( $self, @arg ) = @_;
    
    return undef if $self->onError();
        
    if ( $AUTOLOAD =~ /.*::getHost/ ) {
        my $result = $self->{__Host}; 
        return ( $result ? $result : undef );
    } elsif ( $AUTOLOAD =~ /.*::getProtocol/ ) {
        my $result = $self->{__PROTOCOL}; 
        return ( $result ? $result : undef );
    } elsif ( $AUTOLOAD =~ /.*::getLogin/ ) {
        my $result = $self->{__LOGIN}; 
        return ( $result ? $result : undef );
    } elsif ( $AUTOLOAD =~ /.*::getParam/ ) {
        return $self;
    } elsif ( $AUTOLOAD =~ /.*::DESTROY/ ) {
    } else {
        warn "$AUTOLOAD: method not found";
    }
    return undef;
}
1;
