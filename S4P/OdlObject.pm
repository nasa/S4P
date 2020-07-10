package S4P::OdlObject;

=head1 NAME

OdlObject - ODL object class

=head1 SYNOPSIS

use S4P::OdlObject;

=head1 DESCRIPTION

Encapsulates an ODL object; statements enclosed by "OBJECT=......END_OBJECT=". It is derived from OdlBlock.

=head1 PROJECT

GSFC V0 DAAC

=head1 HISTORY 

Nov 18, 2001
	created.

=head1 AUTHOR

M. Hegde, Raytheon

=cut

################################################################################
# OdlObject.pm,v 1.3 2006/11/22 12:37:36 hegde Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use S4P::OdlBlock;
use vars qw( @ISA );
use strict;

@ISA = ('S4P::OdlBlock');
#*******************************************************************************
sub getNodeType
{
    return( "OBJECT" );
}
1
