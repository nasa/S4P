package S4P::Lexer;

=head1 NAME

 Lexer.pm - a generic lexer class

=head1 SYNOPSIS

use S4P::Lexer;

=head2 Constructor

  $lexer	= S4P::Lexer->new( token1=>value1, token2=>value2, ... );
  
=head2 Accessor methods

  ($token,$value)	= $lexer->extract_next( $input );
  @arr	= $lexer->extract_to( $input, $token );
  @arr	= $lexer->extract_all( $input );

=head1 DESCRIPTION

Provides a generic lexer class. An anonymous function is created from pairs of 
token and value during construction. It provides accessor methods to get the 
next token, extract all tokens etc.,

=head1 DEPENDENCY

None

=head1 KNOWN BUGS

None

=head1 HISTORY

Nov 10, 2001 Created by M. Hegde

=head1 AUTHOR

M. Hegde, Raytheon

=cut

################################################################################
# Lexer.pm,v 1.2 2006/09/12 19:43:49 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

use strict;

sub new
{
    my ( $class, @token_defs ) = @_;
    my ( $code, $pattern, $token, $sub );
    undef $code;
    while ( ($pattern, $token) = splice( @token_defs, 0, 2 ) ){
        $code .= '$_[0] =~ s/\A(\s*' . $pattern . ')// ';

        $code .= ' and return ( "$1", ' . "'$token');\n";
    }
    $code .= '$_[0] =~ s/\A(\s*\S)// and return ( "$1", ""); ';
    $code .= 'return;';

    $sub = eval "sub { $code }" or die;
    bless $sub, ref($class) || $class;
}
#*******************************************************************************
sub extract_next
{
     $_[0]->($_[1]);
}
#*******************************************************************************
sub extract_to
{
    my( @arr, @tokens );
    undef @tokens;
    while ( @arr = $_[0]->($_[1]) ) {
        push( @tokens, @arr );
        last if ( defined $_[2] && ( $arr[1] eq $_[2] ) );
    }
    return( @tokens );
}
#*******************************************************************************
sub extract_all
{
    $_[0]->extract_to( $_[1] );
}
#*******************************************************************************
1
