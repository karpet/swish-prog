package SWISH::Prog::Query;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;

our $VERSION = '0.25_01';

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
    return $self->q->stringify;
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

