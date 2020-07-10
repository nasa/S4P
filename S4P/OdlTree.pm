package S4P::OdlTree;

=head1 NAME

OdlTree - ODL Tree class

=head1 SYNOPSIS

use S4P::OdlTree;

=head2 Constructor

$tree = S4P::OdlTree->new( B<NODE> => B<OdlObject> or B<OdlGroup> );

=head2 Accessor Methods

@limbNodes = $tree->search( B<attr1> => B<value> [,B<attr2> => B<value>, ..] );

=head2 Mutator Methods

$treeLimb = $tree->insert( list of B<OdlObject> or B<OdlGroup> or B<OdlTree> );


=head2 Other Methods

$flag = $tree1->compare( $tree2 );

$text = $tree->toString( [ B<INDENT> => B<indent string>, B<MARGIN> => B<margin string> );

$clone = $tree->clone();


=head1 DESCRIPTION

It encapsulates an ODL tree; statements comprising of ODL objects and classes.

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
# OdlTree.pm,v 1.3 2006/11/22 12:40:52 hegde Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use S4P::OdlObject;
use S4P::OdlGroup;
use S4P::Lexer;
use strict;
use vars '$AUTOLOAD';

{

    ############################################################################
    ############################################################################

    # Declare a reference to dummy anonymous subroutine. This is needed since
    # this subroutine is called recursively. Without this declaration, Perl
    # complains during compilation. If future versions of Perl don't support
    # this work around, make this anonymous subroutine a named subroutine.
    my $_GetToken = sub {};

    # The actual definition of the anonymous sub referred by $_GetToken
    $_GetToken = sub {
        my ( $lexer, $content ) = @_;
       
        my @tokens = $lexer->extract_next( $$content );
        return undef unless @tokens;
    
        if ( $tokens[1] eq 'DBL_QUOTE' or $tokens[1] eq 'SNG_QUOTE' ) {
            # Case of quotes: read until the end of quotes.
            my @arr = $lexer->extract_to( $$content, $tokens[1] );
            push( @tokens, @arr ) if ( @arr );
        } elsif ( $tokens[1] eq 'ULIST_BEG' or $tokens[1] eq 'OLIST_BEG' ) {
            # Case of lists: read until the corresponding end marker is found.
            my $endMarker = ( $tokens[1] eq 'ULIST_BEG' ) 
                            ?  'ULIST_END' : 'OLIST_END';
            
    	    # Read until the end marker is found.
	    while ( 1 ) {
                my @arr = $_GetToken->( $lexer, $content );
                push( @tokens, @arr ) if ( @arr );
                last if ( $arr[1] eq $endMarker );
            }
        } else {
            $tokens[0] =~ s/^\s+|\s+$//g;                
        }
        return @tokens;
    };
    ############################################################################
    
    ############################################################################
    my $_BuildOdlTree = sub {
        my ( %arg ) = @_;
 
        local ( *UNIT );
  
        # Return if a file is not specified in the argument or if the specified
        # file can not be opened for reading.
        return undef unless defined $arg{FILE};
        return undef unless ( open( UNIT, $arg{FILE} ) );
  
        # Read the file content
        my $fileContent;
        {
            local ( $/ ) = undef;
            $fileContent = <UNIT>;
            $fileContent =~ s/end\s+$//i;
            close( UNIT );
        }
  
        # Create the lexer.
        my $parser = {};  
        my $lexer = S4P::Lexer->new( 'OBJECT(?!TYPE)'                   => 'OBJ_BEG',
			        'GROUP(?!TYPE)'                    => 'GRP_BEG',
			        'END_GROUP'                => 'GRP_END',
			        'END_OBJECT'               => 'OBJ_END',
			        '='                        => 'EQ',
			        '\"'                       => 'DBL_QUOTE',
                                q(\')                      => 'SNG_QUOTE',
			        '\('                       => 'ULIST_BEG',
			        '\)'                       => 'ULIST_END',
			        '\{'                       => 'OLIST_BEG',
                                '\}'                       => 'OLIST_END',
			        q([^=\,\"\'\)\(\s\{\}]+)   => 'VAL'
                              );
                              
        my ( @tokens, @nodeList );
        my ( $rootTree, $odlNode, $odlLimb );

        # Remove any comments before parsing.
        
        # Regular expression to detect comments
        my $comment = qr{/\*[^*]*\*+([^/*][^*]*\*+)*/}; 
        # Regular expression to detect matched double quotes
        my $double = qr{(?:\"(?:\\.|[^\"\\])*\")};
        # Combined regular expression for matched double quotes or comments.   
        my $regExp = qr{($double)|$comment};

        # Create a root tree
        $rootTree = S4P::OdlTree->new( );

        # nodeList is used to keep track of the node hierarchy in the tree
        push( @nodeList, $rootTree );

        $odlNode = $rootTree; # Set the current node to the root

        # Replace comments.        
        $fileContent =~ s{$regExp}{$1}g;

        while( @tokens = $lexer->extract_to( $fileContent, 'EQ' ) ) {
                    
            my @rhs = $_GetToken->( $lexer, \$fileContent );
        
            if ( $tokens[1] eq 'GRP_BEG' or $tokens[1] eq 'OBJ_BEG' ) {
            
                # If a group/object name is not defined, return undef
                unless ( @rhs ) {
                    warn "Undefined name for $tokens[0]";
                    return undef;
                }
                
                # Create an ODL group or object depending on LHS.   
                $odlNode = ( $tokens[1] eq 'GRP_BEG' )
                           ? S4P::OdlGroup->new( NAME => $rhs[0])
                           : S4P::OdlObject->new( NAME => $rhs[0] );
                # Create an ODL limb with the newly created ODL group/object.
                $odlLimb = S4P::OdlTree->new( NODE => $odlNode );

                # If a parent node is defined, make the newly created node 
                # its child.                
                $nodeList[$#nodeList]->insert( $odlLimb) if ( @nodeList );
                
                # If the root of the tree is not defined, make the new node the
                # root.
                $rootTree = $odlLimb unless defined $rootTree;
                
                # Push to the stack of ODL node tree.
                push( @nodeList, $odlLimb );
            
            } elsif ( $tokens[1] eq 'GRP_END' or $tokens[1] eq 'OBJ_END' ) {
            
                # Since it is the end of the group/object, pop the node stack.
                pop( @nodeList ) if ( @nodeList );

            } else {
        
                my $val = '';
                for ( my $i = 0 ; $i < @rhs ; $i+=2 ) {
                    $val .= $rhs[$i];
                }
            
                $tokens[0] =~ s/^\s+|\s+$//g;
                $val =~ s/^\s+|\s+$//g;
                $odlNode->setAttribute( $tokens[0] => $val ) 
                    if ( defined $odlNode and @rhs );
            }
        }
	# Look for an unbalanced tree
        if ( @nodeList > 1 ) {
            print STDERR "Error; unbalanced tree:\n";
            foreach my $node ( reverse @nodeList ) {
                last if ( $node == $rootTree );
                print STDERR "    ", $node->getNodeType(), "=",
                    , $node->getNode()->getName() , " unbalanced\n";
            }
            undef $rootTree;
        }
        return $rootTree;
    };
 
    ###########################################################################
    # ^NAME:
    #   new
    #
    # ^DESCRIPTION: 
    #   Constructor; can take an OdlTree or OdlGroup object as an argument.
    #
    # ^SYNOPSIS:
    #   S4P::OdlTree->new( [NODE => OdlObject or OdlGroup] );
    #
    # ^RETURN VALUE:
    #   OdlTree object
    ###########################################################################
    sub new
    {
        my ( $class, %arg ) = @_;
    
        if ( defined $arg{FILE} ) {
            return $_BuildOdlTree->( %arg );    
        } else {
            my $tree = { _NODE => undef, _LIMBS => [] };
            $tree->{_NODE} = ( defined $arg{NODE} ) 
                             ? $arg{NODE} : S4P::OdlObject->new();
            return bless $tree, $class;
        }
    }
}

################################################################################
# ^NAME
#   AUTOLOAD
#
# ^DESCRIPTION: 
#   a generic handler for set/get methods, destructor ...
#
# ^SYNOPSIS:
#   $odlTree->getNode();
#   $odlTree->getLimbs();
#   $odlTree->getAttribute( attrName, ... );
#   $odlTree->setAttribute( attrName => attrValue, ... );   
#
# ^RETURN VALUE:
#   getNode() returns an object of the type OdlGroup or OdlObject.
#   getLimbs() returns an array containing all the limbs of the tree.
#   getAttribute() returns a list of requested attributes.
#
################################################################################
sub AUTOLOAD
{
    my ( $self, @arg ) = @_;

    # match the called function name and act accordingly
    if ( $AUTOLOAD =~ /.*::getNodeType/ ) {
    
        return $self->getNode()->getNodeType();
        
    } elsif ( $AUTOLOAD =~ /.*::getNode/ ) {
    
        # returns the object in the current node
        return( $self->{_NODE} );
        
    } elsif ( $AUTOLOAD =~ /.*::getLimbs/ ) {  
    
        # return the limbs array
        return( @{$self->{_LIMBS}} );
        
    } elsif ( $AUTOLOAD =~ /.*::getAttribute/ ) {

        return( $self->{_NODE}->getAttribute( @arg ) );
        
    } elsif ( $AUTOLOAD =~ /.*::setAttribute/ ) {
    
        return( $self->{_NODE}->setAttribute( @arg ) );
        
    } elsif ( $AUTOLOAD =~ /.*::delAttribute/ ) {
    
        return( $self->{_NODE}->delAttribute( @arg ) );
             
    } elsif ( $AUTOLOAD =~ /.*::DESTROY/ ) {
 
        # destructor: no special action needed

    } else {
 
        # if no match found, just die
        die "$AUTOLOAD not defined:", 
            '(File=', __FILE__, ', Line=', __LINE__, ")\n";
        
    }
}

################################################################################
# ^NAME:
#   insert
#
# ^DESCRIPTION: 
#   inserts one ore more OdlGroup, OdlObject or OdlTree objects in to a tree. 
#   Non OdlTree objects are converted to OdlTree using constructor.
#
# ^SYNOPSIS:
#   @limbs = $odlTree->insert( $odlObj1, $odlGroup1, $odlTree1 );
#
# ^RETURN VALUE:
#   An array (scalar if a scalar is passed as argument) of OdlTree (limbs) that
#   were inserted.
#	
################################################################################
sub insert
{
    my ( $self, @objList ) = @_;
      
    my ( $type, $tree, @treeList );
    
    # index through passed objects
    for ( my $i = 0 ; $i <= $#objList ; $i++ ) {
        # determine the type of object
        $type = ref( $objList[$i] );

        # if it is an OdlTree, use it; otherwise create one
        $tree = ( $type eq 'S4P::OdlGroup' || $type eq 'S4P::OdlObject' ) ?
                    S4P::OdlTree->new( NODE => $objList[$i] ) :
                ( $type eq 'S4P::OdlTree' ) ? ( $objList[$i] ) : ( undef );

        if ( defined $tree ) {
            push( @{$self->{_LIMBS}}, $tree ) ;
            push( @treeList, $tree );
        }
        
        undef $tree;
    } 
    
    # return the limbs (trees) created
    return @treeList if ( scalar(@treeList) > 1 );
    return $treeList[0]; 
}

################################################################################
# ^NAME:
#   delete
#
# ^DESCRIPTION: 
#   Deletes groups/objects within the specified ODL tree which contain specified
#   attributes.
#
# ^SYNOPSIS:
#   $odlTree->delete( <attribute hash> );
#
# ^RETURN VALUE:
#   Returns 1 if the root node of the OdlTree is removed. Return 0 otherwise.	
################################################################################
sub delete
{
    my ( $self, %arg ) = @_;
    
    my $node = $self->getNode();
    
    # for all the limbs of the tree, do a delete()
    my @limbList = $self->getLimbs();
    
    my ( @list, @result );    
    for ( my $i = 0 ; $i <= $#limbList ;  ) {
        if ( $limbList[$i]->delete( %arg ) ) {
            # If a node is to be deleted, remove it from the list of limbs at
            # the current node.
            undef $limbList[$i];
            splice( @limbList, $i, 1 );
        } else {
            $i++;
        }        
    }
    @{$self->{_LIMBS}} = @limbList;
    
    # check the current node and save the current limb in the "result" array if
    # it matches
    my $status = $node->search( %arg );
    return $status;
}
################################################################################
# ^NAME:
#   compare
#
# ^DESCRIPTION: 
#   compares the tree with another tree. NOTE: At the same level, ODL 
#   group/objects are position independent.
#
# ^SYNOPSIS:
#   $odlTree1->compare( $odlTree2 ); 
#
# ^RETURN VALUE:
#   0/1 => don't match/match	
###############################################################################
sub compare
{
    my ( $self, $target ) = @_;
    
    # return false for type mismatch
    return( 0 ) if( ref($self) ne ref($target) );
    
    # compare respective nodes
    my $node1 = $self->getNode();
    my $node2 = $target->getNode();
    
    # if the nodes themselves don't compare
    $node1->compare( $node2 ) || return( 0 );
    
    # get all the limbs
    my @selfNodes = $self->getLimbs();
    my @targetNodes = $target->getLimbs();
    
    # if number of limbs mismatch, return 0
    return( 0 ) if ( scalar(@selfNodes) ne scalar(@targetNodes) );
    
    # recursively compare individual limbs
    my ( $selfLimb, $targetLimb, $status );
    foreach $selfLimb ( @selfNodes ) {
        foreach $targetLimb ( @targetNodes ) {
            $status = $selfLimb->compare( $targetLimb );
            last if ( $status );
        }
    }
    
    # return 1 if everything matches
    return( 1 );
}

################################################################################
# ^NAME:
#   search
#
# ^DESCRIPTION: 
#   Searches for a node containing specified attributes/values combination. 
#   Descends down the tree comparing the limbsMakes 
#
# ^SYNOPSIS:
#   odlTree->search(  'Attribute Name' => 'Attribute value', ... );
# 
# ^RETURN VALUE:
#	
################################################################################
sub search
{
    my ( $self, %arg ) = @_;
    
    my $node = $self->getNode();
    
    # for all the limbs of the tree, do a search()
    my @limbList = $self->getLimbs();
    
    my ( @list, @result );    
    for ( my $i = 0 ; $i <= $#limbList ; $i++ ) {
        @list = $limbList[$i]->search( %arg );
        # save the limbs matching the input in the "result" array
        push( @result, @list ) if ( scalar(@list) ); 
    }
    
    # check the current node and save the current limb in the "result" array if
    # it matches
    my $status = $node->search( %arg );
    push( @result, $self ) if ( $status );
    
    # return the result array  
    return @result;
}

################################################################################
# ^NAME: 
#   toString
#
# ^DESCRIPTION:
#   converts OdlTree to a ODL format string. 
#
# ^SYNOPSIS:
#   $odlTree->toString( INDENT => <indent value>, MARGIN => <marging value> );
# 
# ^RETURN VALUE:
#   A string representing OdlTree.
################################################################################
sub toString
{
    my ( $self, %arg ) = @_;
    
    # default indentation and margin
    $arg{INDENT} = "\t" if ( ! defined $arg{INDENT} );
    $arg{MARGIN} = '' if( ! defined $arg{MARGIN} );
    
    my $indent = $arg{INDENT};  # save the indent value before recursion begins
    
    # get the node name
    my $nodeName = $self->{_NODE}->getName();
    
    $arg{INDENT} = '' if ( $nodeName eq '' );
    
    # make a recursive call to convert the individual node of the tree to text
    my( $header, $body, $footer ) = $self->{_NODE}->toString( %arg );
    
    $arg{INDENT} = $indent; # retrieve the indent value saved before recursion
    
    my $str = ( $nodeName ne '' ) ? ( $header . $body ) : ( $body );
    
    $arg{MARGIN} .= $arg{INDENT} if ( $nodeName ne '' );    
    foreach my $child ( @{$self->{_LIMBS}} ) {
        # make a recursive call to print all the limbs of the tree
        $str .= $child->toString( %arg );
    }
    
    $str .= $footer if ( $nodeName ne '' );
    
    return( $str );
}

################################################################################
# ^NAME: 
#   clone
#
# ^DESCRIPTION:
#   clones OdlTree object by duplicating individual limbs in the tree 
#   recursively 
#
# ^SYNOPSIS:
#   $clone = $odlTree->clone();
# 
# ^RETURN VALUE:
#   An OdlTree object
################################################################################
sub clone
{
    my ( $self ) = @_;
    
    # clone the node
    my $node = $self->getNode();
    
    # create the new tree
    my $tree = S4P::OdlTree->new( NODE => $node->clone() );
    
    # get the limbs in the source tree
    my @limbList = $self->getLimbs();
    
    my ( $limb, $cloneLimb );
    
    # clone the limbs
    foreach $limb ( @limbList ) {
        $cloneLimb = $limb->clone();
        $tree->insert( $cloneLimb );
    }
    return( $tree );    
}

1
