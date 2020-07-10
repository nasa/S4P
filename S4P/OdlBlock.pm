package S4P::OdlBlock;

=head1 NAME

OdlBlock - ODL block class

=head1 SYNOPSIS

use S4P::OdlBlock;

=head2 Constructor

$block = S4P::OdlBlock->new( B<NAME> => B<'Block name'>, 
            B<'Attribute name'> => B<'Attribute value'>, ... ); 

This is intended to be a virtual class; use OdlGroup or OdlObject classes instead.

=head2 Accessor Methods

$attrValue = $block->getAttribute( B<'Attribute name'> );

$str = $block->toString(Z<>);

$name = $block->getName(Z<>);

$block->isAttribute( B<'Attribute name'> );

$block->search( B<'Attribute name'> => 
                        B<'Attribute value'>, ... );

=head2 Mutator Methods

$block->delAttribute( B<'Attribute name'> );

$block->setAttribute( B<'Attribute name'> => 
                        B<'Attribute value'>, ...);

$block->setName( B<'Name'> );

=head2 Other Methods

$block->clone(Z<>);

$block->compare(Z<>);

=head1 DESCRIPTION

It encapsulates an ODL block; statements enclosed by "GROUP/OBJECT=......END_GROUP/END_OBJECT=".

=over

=head1 PROJECT

GSFC V0 DAAC

=head1 HISTORY 

Nov 18, 2001
	created.

=head1 AUTHOR

M. Hegde, Raytheon

=cut

################################################################################
# OdlBlock.pm,v 1.3 2006/11/22 12:36:01 s4pa Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;
use vars '$AUTOLOAD';

{

    ############################################################################
    # ^NAME
    #   new
    #
    # ^DESCRIPTION: 
    #	Constructor
    #
    # ^SYNOPSIS:
    #	This is an internal class not to be used directly.
    #	$obj	= S4P::OdlBlock->new( NAME => <name>, 
    #			<Attribute Name> => <value>, ... );
    #
    # ^RETURN VALUE:
    #	OdlBlock object
    ############################################################################
    sub new
    {
        my ( $class, @attrList ) = @_;

        # hash reference to hold the object
        my $odl = {};

        # array to hold attribute names; array order represents the order in 
        # which attributes were set
        my $arrRef = [];  
        
        my ( $newKey, $i );
        
        $odl->{_NAME} = '';
        for ( $i = 0 ; $i <= $#attrList ; $i += 2 ) {
            $newKey = uc( $attrList[$i] );
            if ( $newKey eq 'NAME' ) {
                $odl->{_NAME} = $attrList[$i+1];
            } else {
                $odl->{$newKey} = $attrList[$i+1];
                push( @{$arrRef}, $newKey );
            }
        }        
        
        $odl->{_ATTR_LIST} = $arrRef;

        return bless $odl, $class;
    }
}

################################################################################
# ^NAME
#   AUTOLOAD
#
# ^DESCRIPTION: 
#   a generic handler for 'set'/'get' methods, destructor ...
#
# ^SYNOPSIS:
#   $obj->getAttribute( <Attribute Name> );
#   $obj->getName();
#   $obj->setName();
#   $obj->listAttributes();
#
# ^RETURN VALUE:
#   Returns the object attribute/undef.
################################################################################
sub AUTOLOAD
{
    my ( $self, @arg ) = @_;

    # match the called function name and act accordingly
    if ( $AUTOLOAD =~ /.*::getAttribute/ ) {
 
        # returns the attribute value; expects only single argument
        return undef if( scalar(@arg) != 1 );
        return $self->{uc($arg[0])};
    
    } elsif ( $AUTOLOAD =~ /.*::getName/ ) {
 
        # returns the name of the OdlBlock
        return $self->getAttribute( '_NAME' );
    
    } elsif ( $AUTOLOAD =~ /.*::setName/ ) {
 
        # sets the name of the OdlBlock
        $self->{_NAME} = $arg[0];
    
    } elsif ( $AUTOLOAD =~ /.*::get(.+)/ ) {
 
        # returns the attribute value when invoked as 
        # S4P::OdlObject::get<Attribute name>()
        return $self->{uc("$1")};
        
    } elsif( $AUTOLOAD =~ /.*::isAttribute/ ) {

        # check whether an attribute is defined or not
        return( defined $self->{uc($arg[0])} );
    
    } elsif ( $AUTOLOAD =~ /.*::listAttributes/ ) {
 
        # returns the attribute list as an array
        return( @{$self->{_ATTR_LIST}} );
    
    } elsif ( $AUTOLOAD =~ /.*::DESTROY/ ) {
 
        # destructor: no special action needed
    
    } else {
 
        # if no match found, just die
        die "$AUTOLOAD not defined:", 
            '(File=', __FILE__, ', Line=', __LINE__, ")\n";
        
    }
}

################################################################################
# ^NAME
#   setAttribute
#
# ^DESCRIPTION: 
#   setAttribute - a method to set attribute values
#
# ^SYNOPSIS:
#   $obj->setAttribute( <Attribute Name> => <value>, ... );
#
# ^RETURN VALUE:
#   0/1 => failure/success
################################################################################
sub setAttribute
{
    my ( $self, @attrList ) = @_;

    # fail if no arguments are specified
    return( 0 ) if ( scalar(@attrList) <= 0 );
    
    # fail if arguments are not specified in "key=>value" format
    return( 0 ) if ( scalar(@attrList) % 2 != 0 );

    # set the attributes
    my $arrRef = $self->{_ATTR_LIST};
    my( $newKey );
    for( my $i=0 ; $i <= $#attrList ; $i+=2 ){
        # store all attribute names to upper case
        $newKey = uc($attrList[$i]);
        
        # store in the attribute list if it is a new attribute
        push( @$arrRef, $newKey ) if( ! defined $self->{$newKey} );
        
        $self->{$newKey} = $attrList[$i+1];
    }
    return( 1 );
}

################################################################################
# ^NAME
#   delAttribute
#
# ^DESCRIPTION: 
#   'delete' method for attributes.
#
# ^SYNOPSIS:
#   $obj->delAttribute( <ATTRIBUTE_NAME_LIST> );
#
# ^RETURN VALUE:
#   Attribute value or undef
################################################################################
sub delAttribute
{
    my ( $self, @arg ) = @_;
    
    # get the attribute list in the object
    my $arrRef = $self->{_ATTR_LIST};
    
    # loop through each element in the attribute list and delete it
    my ( $elem, $attr, $i );
    foreach $elem ( @arg ){
        $attr = uc($elem);
        delete $self->{$attr};
        for ( $i=0 ; $i< @{$arrRef} ; $i++ ){
            next if ( $arrRef->[$i] ne $attr );
        
            # delete the attribute from the attribute list
            splice( @$arrRef, $i, 1 );
            last;
        }
    }
}

################################################################################
# ^NAME:
#   toString
#
# ^DESCRIPTION: 
#   toString - a method to print object to a string
#
# ^SYNOPSIS:
#   $obj->toString();
#
# ^ARGUMENTS:
#   MARGIN  => left margin (string); default = ''
#   INDENT  => indentation; default = "\t"
#
# ^RETURN VALUE:
#   a multi-line scalar showing object contents in ODL format.
################################################################################
sub toString
{
    my ( $self, %arg ) = @_;

    $arg{INDENT} = "\t" if( ! defined $arg{INDENT} ); 
    $arg{MARGIN} = '' if( ! defined $arg{MARGIN} );

    my $type = ( ref($self) eq 'S4P::OdlGroup' ) ? ( 'GROUP' ) :
                   ( ref($self) eq 'S4P::OdlObject' ) ? ( 'OBJECT' ) : '';
                   
    my $header = $arg{MARGIN} . $type . ' = ' . 
                    $self->getAttribute( '_NAME' ) . "\n";
                    
    my $body = '';
    my $attr;
    foreach $attr ( @{$self->{_ATTR_LIST}} ) {
        $body .= $arg{MARGIN} . $arg{INDENT} . $attr . ' = ' .  
                    $self->{$attr} . "\n";
    }
    
    my $footer = $arg{MARGIN} . 'END_' . $type . ' = ' . 
                    $self->getName() . "\n";

    return( $header, $body, $footer ) ;
}

################################################################################
# ^NAME:
#   clone
#
# ^DESCRIPTION: 
#   clone - a method to clone an OdlBlock or its derived classes
#
# ^SYNOPSIS:
#   $obj->clone();
#
# ^RETURN VALUE:
#   a cloned OdlBlock/derived class (OdlGroup/OdlObject) object
################################################################################
sub clone
{
    my ( $self ) = @_;

    # create a new S4P::OdlObject
    my $odl = S4P::OdlBlock->new( NAME=>$self->getName() );
 
    # get the attribute list
    my @attr_list = $self->listAttributes();
 
    # add the attributes to the newly created OdlBlock
    for ( my $i=0 ; $i<=$#attr_list ; $i++ ) {
        $odl->setAttribute( 
            $attr_list[$i] => $self->getAttribute( $attr_list[$i] )
        );	
    }
 
    # bless the object as the class of calling object and return
    return bless $odl, ref($self);
}

################################################################################
# ^NAME:
#   compare
#
# ^DESCRIPTION: 
#   compare - a method to compare two OdlBlock objects.
#
# ^SYNOPSIS:
#   $obj1->compare( $obj2 );
#
# ^RETURN VALUE:
#   1/0 => success/failure
################################################################################
sub compare
{
    my ( $self, $target ) = @_;
 
    # return failure if types mismatch
    return( 0 ) if ( ref($self) ne ref($target) );

    # return 0 if names mismatch
    return( 0 ) if ( $self->getName() ne $target->getName() );

    # get the attribute list of each
    my @selfAttrList = sort( $self->listAttributes() );
    my @targetAttrList = sort( $target->listAttributes() );

    # return 0 if # of attributes mismatch
    return( 0 ) if ( scalar(@selfAttrList) != scalar(@targetAttrList) );

    # compare values of each attribute 
    for ( my $i=0 ; $i<=$#selfAttrList ; $i++ ) {
        return( 0 ) if ( $self->getAttribute($selfAttrList[$i]) ne 
				$target->getAttribute($targetAttrList[$i]) );
    }
    return( 1 );
}

################################################################################
# ^NAME:
#   search
#
# ^DESCRIPTION: 
#   search - a method to search OdlBlock object for specified attribute-value
#   pairs.
#
# ^SYNOPSIS:
#   $obj1->search( <attribute name> => <attribute value> ... );
#
# ^RETURN VALUE:
#   1/0 => match found/not found.
################################################################################
sub search
{
    my ( $self, %arg ) = @_;
    
    # convert all attribute names to upper case
    my ( $oldKey, $newKey );
    foreach $oldKey ( keys(%arg) ) {
        $newKey = uc( $oldKey );
        if ( $newKey ne $oldKey ) {
            $arg{$newKey} = $arg{$oldKey};
            delete $arg{$oldKey};
        }
    }
    
    my $flag = $arg{__CASE_INSENSITIVE__} ? 1 : 0;
    delete $arg{__CASE_INSENSITIVE__};
    if ( $flag ) {
        return 0 if ( defined $arg{NAME} 
            && uc($self->getName()) ne uc($arg{NAME}) );
    } else {
        return 0 if ( defined $arg{NAME} && ($self->getName() ne $arg{NAME}) );
    }

    
    delete $arg{NAME};
    
    my @attrList = keys( %arg );
    for ( my $i = 0 ; $i < @attrList ; $i++ ) {
        return 0 if ( ! $self->isAttribute( $attrList[$i] ) );
        return 0 
            if ( $self->getAttribute( $attrList[$i] ) ne $arg{$attrList[$i]} );
        return 0
            if ( $flag && 
                 ( uc($self->getAttribute( $attrList[$i] )) ne 
                   uc($arg{$attrList[$i]}) ) );
    }
    return 1;    
}
1
