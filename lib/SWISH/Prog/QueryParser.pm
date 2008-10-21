package SWISH::Prog::QueryParser;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;
use POSIX qw(locale_h);    # make sure we get correct ->utf8 encoding
use locale;
use Search::Tools::UTF8;
use Search::QueryParser;
use SWISH::Prog::Query;

our $VERSION = '0.21';

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
        ),
);

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

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

    $self->{parser} = Search::QueryParser->new(
        rxAnd => qr{$self->{and_word}}i,
        rxOr  => qr{$self->{or_word}}i,
        rxNot => qr{$self->{not_word}}i,
    );

}

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
    return SWISH::Prog::Query->new( q => $q, parser => $self->{parser} );
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
