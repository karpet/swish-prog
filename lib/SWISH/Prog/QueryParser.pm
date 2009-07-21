package SWISH::Prog::QueryParser;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;
use POSIX qw(locale_h);    # make sure we get correct ->utf8 encoding
use locale;
use Search::Tools::UTF8;
use Search::QueryParser::SQL;
use SWISH::Prog::Query;

our $VERSION = '0.27_01';

__PACKAGE__->mk_accessors(
    qw(
        and_word
        or_word
        not_word
        stopwords
        wildcard
        ignore_case
        parser
        locale
        lang
        charset
        query_class
        config
        ),
);

=head1 NAME

SWISH::Prog::QueryParser - turn text strings into Query objects

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
        config          => $swish_prog_config,
    );
 my $query = $parser->parse( 'foo not bar or bing' );

=head1 DESCRIPTION

SWISH::Prog::QueryParser turns text strings into Query objects.
The query class defaults to SWISH::Prog::Query but you can
set it in the new() method.

This class depends on Search::QueryParser::SQL for the heavy lifting.
See the documentation for Search::QueryParser::SQL for details
on affecting the parsing behaviour.

=head1 METHODS


=head2 init

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    if ( !$self->config ) {
        croak "SWISH::Prog::Config object required";
    }

    # set defaults
    $self->{locale} ||= setlocale(LC_CTYPE);
    ( $self->{lang}, $self->{charset} ) = split( m/\./, $self->{locale} );
    $self->{lang} = 'en_US' if $self->{lang} =~ m/^(posix|c)$/i;
    $self->{charset}      ||= 'iso-8859-1';
    $self->{phrase_delim} ||= '"';
    $self->{and_word}     ||= 'and|near\d*';
    $self->{or_word}      ||= 'or';
    $self->{not_word}     ||= 'not';
    $self->{wildcard}     ||= '*';
    $self->{stopwords}    ||= [];
    $self->{ignore_case} = 1 unless defined $self->{ignore_case};
    $self->{query_class} ||= 'SWISH::Prog::Query';

    $self->{parser} = Search::QueryParser::SQL->new(
        columns => [
            qw( swishdefault swishtitle ),
            @{ $self->{config}->all_metanames }
        ],
        default_column => 'swishdefault',
        strict         => 1,
    );

}

=head2 parse( I<string> )

Returns a Query object blessed into query_class().

=cut

sub parse {
    my $self = shift;
    my $str  = shift;
    if ( !defined($str) ) {
        croak "query string required";
    }
    $str = lc($str) if $self->ignore_case;
    $str = to_utf8($str);
    my $q = $self->{parser}->parse( $str, 1 )
        or croak $self->{parser}->err;
    return $self->{query_class}->new(
        q      => $q,
        parser => $self->{parser},
        __qp   => $self,
    );
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
