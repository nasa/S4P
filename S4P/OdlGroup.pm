package S4P::OdlGroup;

=head1 NAME

OdlGroup - ODL group class

=head1 SYNOPSIS

use S4P::OdlGroup;

=head1 DESCRIPTION

Encapsulates an ODL block; statements enclosed by "GROUP=......END_GROUP=". It is derived from OdlBlock.

=head1 PROJECT

GSFC V0 DAAC

=head1 HISTORY 

Nov 18, 2001
	created.

=head1 AUTHOR

M. Hegde, Raytheon

=cut

################################################################################
# OdlGroup.pm,v 1.3 2006/11/22 12:37:20 hegde Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use S4P::OdlBlock;
use vars qw( @ISA );
use strict;

@ISA = ('S4P::OdlBlock');
#*******************************************************************************
sub getNodeType
{
    return "GROUP";
}
1
