package SWISH::Prog::Query;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;

our $VERSION = '0.27_01';

__PACKAGE__->mk_ro_accessors(qw( q parser ));

use overload(
    '""'     => \&stringify,
    fallback => 1,
);

=head1 NAME

SWISH::Prog::Query - a Query object base class

=head1 SYNOPSIS

 my $parser = SWISH::Prog::QueryParser->new(
        charset         => 'iso-8859-1',
        phrase_delim    => '"',
        and_word        => 'and',
        or_word         => 'or',
        not_word        => 'not',
        wildcard        => '*',
        stopwords       => [],
        ignore_case     => 1,
        query_class     => 'SWISH::Prog::Query',
    );
 my $query = $parser->parse( 'foo not bar or bing' );

=head1 DESCRIPTION

SWISH::Prog::Query is a base class representing a query.
You create Query objects and pass them to a Searcher.

=head1 METHODS


=head2 stringify

Turn the object back into string. This method is called
whenever the object is printed.

=cut

sub stringify {
    my $self = shift;
    return $self->swish2;
}

=head2 swish2

Returns query as Swish-e version 2.x-compatible string.

=cut

sub swish2 {
    my $self = shift;
    my $q    = $self->q;    # Search::QueryParser::SQL::Query object

    # based on dbi() method in SQSQ class
    # set flag temporarily
    $q->{opts}->{delims} = 1;

    my $sql = $q->_unwind;
    my @values;
    my $start   = chr(2);
    my $end     = chr(3);
    my $opstart = chr(5);
    my $opend   = chr(6);

    $sql =~ s/([\w\.]+)\ ?$opstart(!=)$opend/NOT $1=/g;
    $sql =~ s/($start|$end|$opstart|$opend)//g;           # no ctrl chars

    delete $q->{opts}->{delims};

    return $sql;
}

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

