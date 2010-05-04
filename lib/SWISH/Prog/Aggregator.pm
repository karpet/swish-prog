package SWISH::Prog::Aggregator;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;
use SWISH::Prog::Utils;
use SWISH::Filter;
use SWISH::Prog::Doc;
use Scalar::Util qw( blessed );
use Data::Dump qw( dump );

our $VERSION = '0.45';

__PACKAGE__->mk_accessors(
    qw(
        set_parser_from_type
        indexer
        doc_class
        swish_filter_obj
        test_mode filter
        ok_if_newer_than
        progress_size
        )
);
__PACKAGE__->mk_ro_accessors(qw( count ));

=pod

=head1 NAME

SWISH::Prog::Aggregator - document aggregation base class

=head1 SYNOPSIS

 package MyAggregator;
 use strict;
 use base qw( SWISH::Prog::Aggregator );
 
 sub get_doc {
    my ($self, $url) = @_;
    
    # do something to create a SWISH::Prog::Doc object from $url
    
    return $doc;
 }
 
 sub crawl {
    my ($self, @where) = @_;
    
    foreach my $place (@where) {
       
       # do something to search $place for docs to pass to get_doc()
       
    }
 }
 
 1;

=head1 DESCRIPTION

SWISH::Prog::Aggregator is a base class that defines the basic API for writing
an aggregator. Only two methods are required: get_doc() and crawl(). See
the SYNOPSIS for the prototypes.

See SWISH::Prog::Aggregator::FS and SWISH::Prog::Aggregator::Spider for examples
of aggregators that crawl the filesystem and web, respectively.

=head1 METHODS

=head2 init

Set object flags per SWISH::Prog::Class API. These are also accessors, 
and include:

=over

=item set_parser_from_type

This will set the parser() value in swish_filter() based on the
MIME type of the doc_class() object.

=item indexer

A SWISH::Prog::Indexer object.

=item doc_class

The name of the SWISH::Prog::Doc-derived class to use in get_doc().
Default is SWISH::Prog::Doc.

=item swish_filter_obj

A SWISH::Filter object. If not passed in new() one is created for you.

=item test_mode

Dry run mode, just prints info on stderr but does not
build index.

=item filter

Value should be a CODE ref. This is passed through to set_filter();
there is no C<filter> mutator method.

=item ok_if_newer_than

Value should be a Unix timestamp (epoch seconds). Default is undef.
If set, aggregators should skip files that have a modification time
older than the timestamp.

You may get/set the ok_if_newer_than value with the ok_if_newer_than()
attribute method, but use set_ok_if_newer_than() to include validation
of the supplied I<timestamp> value.

=item progress_size( I<n> )

If set (defaults to C<1000>), the Aggregator may choose to
report progress every <n> doc crawl()ed. The FS Aggregator (for example)
will print a line to stdout every I<n> docs.

=back

=cut

sub init {
    my $self   = shift;
    my %arg    = @_;
    my $filter = delete $arg{filter};
    $self->SUPER::init(%arg);
    $self->{verbose} ||= 0;
    $self->{progress_size} = 1000 unless defined $self->{progress_size};

    if (   !$self->{indexer}
        or !blessed( $self->{indexer} )
        or !$self->{indexer}->isa('SWISH::Prog::Indexer') )
    {
        croak "SWISH::Prog::Indexer-derived object required to crawl()";
    }

    $self->{doc_class} ||= 'SWISH::Prog::Doc';
    $self->{swish_filter_obj} ||= SWISH::Filter->new;

    if ($filter) {
        $self->set_filter($filter);
    }

}

=head2 config

Returns the SWISH::Prog::Config object from the Indexer
being used. This is a read-only method (accessor not mutator).

=cut

sub config {
    return shift->{indexer}->config;
}

=head2 count

Returns the total number of doc_class() objects returned by get_doc().

=cut

=head2 crawl( I<@where> )

Override this method in your subclass. It does the aggregation,
and passes each doc_class() object from get_doc() to indexer->process().

=cut

sub crawl {
    my $self = shift;
    croak ref($self) . " does not implement crawl()";
}

=head2 get_doc( I<url> )

Override this method in your subclass. Should return a doc_class()
object.

=cut

sub get_doc {
    my $self = shift;
    croak ref($self) . " does not implement get_doc()";
}

=head2 swish_filter( I<doc_class_object> )

Passes the content() of the SPD object through SWISH::Filter
and transforms it to something index-able. Returns
the I<doc_class_object>, filtered.

B<NOTE:> This method should be called by all aggregators after
get_doc() and before passing to the indexer().

See the SWISH::Filter documentation.

=cut

sub swish_filter {
    my $self = shift;
    my $doc  = shift;
    unless ( $doc && blessed($doc) && $doc->isa('SWISH::Prog::Doc') ) {
        croak "SWISH::Prog::Doc-derived object required";
    }

    $doc->parser( $SWISH::Prog::Utils::ParserTypes{ $doc->type }
            || $SWISH::Prog::Utils::ParserTypes{default} )
        if $self->set_parser_from_type;

    if ( $self->{swish_filter_obj}->can_filter( $doc->type ) ) {
        my $content = $doc->content;
        my $url     = $doc->url;
        my $type    = $doc->type;
        my $f       = $self->{swish_filter_obj}->convert(
            document     => \$content,
            content_type => $type,
            name         => $url
        );

        if (   !$f
            || !$f->was_filtered
            || $f->is_binary )    # is is_binary necessary?
        {
            warn "skipping $url - filtering error\n";
            return;
        }

        $doc->content( ${ $f->fetch_doc } );

        # leave type and parser as-is
        # since we want to store original mime in indexer
        # TODO what about parser ?
        # since type will have changed ( $f->content_type ) from original
        # the parser type might also have changed?

        $doc->parser( $f->swish_parser_type ) if $self->set_parser_from_type;

    }

}

=head2 set_filter( I<code_ref> )

Use I<code_ref> as the C<doc_class> filter. This method called by init() if
C<filter> param set in constructor.

=cut

sub set_filter {
    my $self   = shift;
    my $filter = shift;
    unless ( ref($filter) eq 'CODE' ) {
        croak "filter must be a CODE ref";
    }

    # cheat a little by using this code instead of the default
    # method in doc_class
    {
        no strict 'refs';
        no warnings 'redefine';
        *{ $self->{doc_class} . '::filter' } = $filter;
    }

}

=head2 set_ok_if_newer_than( I<timestamp> )

Set the ok_if_newer_than attribute. I<timestamp> should be a Unix
epoch value.

=cut

sub set_ok_if_newer_than {
    my $self = shift;
    my $ts = shift || 0;
    if ( $ts =~ m/\D/ ) {
        croak "timestamp should be an integer";
    }
    $self->ok_if_newer_than($ts);
}

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 BUGS

Please report any bugs or feature requests to C<bug-swish-prog at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SWISH-Prog>.  
I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SWISH::Prog


You can also look for information at:

=over 4

=item * Mailing list

L<http://lists.swish-e.org/listinfo/users>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SWISH-Prog>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SWISH-Prog>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SWISH-Prog>

=item * Search CPAN

L<http://search.cpan.org/dist/SWISH-Prog/>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 SEE ALSO

L<http://swish-e.org/>
