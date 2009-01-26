package SWISH::Prog::InvIndex;

use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;
use Path::Class;
use Scalar::Util qw( blessed );
use SWISH::Prog::InvIndex::Meta;
use overload(
    '""'     => sub { shift->path },
    fallback => 1,
);

our $VERSION = '0.25';

__PACKAGE__->mk_accessors(qw( path clobber ));

sub init {
    my $self = shift;
    my $path = $self->{path} || $self->{invindex} || 'index.swish';

    unless ( blessed($path) && $path->isa('Path::Class::Dir') ) {
        $self->path( dir($path) );
    }

    $self->{clobber} = 0 unless exists $self->{clobber};
}

sub new_from_meta {
    my $self = shift;

    # open swish.xml meta file
    my $meta = $self->meta;

    # parse for index format
    my $format = $meta->Index->{Format};

    # create new object and re-set $self
    my $newclass = "SWISH::Prog::${format}::InvIndex";

    warn "reblessing $self into $newclass";

    eval "require $newclass";
    croak $@ if $@;

    return $newclass->new(
        path    => $self->{path},
        clobber => $self->{clobber},
    );
}

sub open {
    my $self = shift;

    if ( -d $self->path && $self->clobber ) {
        $self->path->rmtree( $self->verbose, 1 );
    }
    elsif ( -f $self->path ) {
        croak $self->path
            . " is not a directory -- won't even attempt to clobber";
    }

    if ( !-d $self->path ) {
        carp "no path $self->{path} -- mkpath";
        $self->path->mkpath( $self->verbose );
    }

    1;
}

sub open_ro {
    shift->open(@_);
}

sub close { 1; }

sub meta {
    my $self = shift;
    return SWISH::Prog::InvIndex::Meta->new( invindex => $self );
}

=pod

=head1 NAME

SWISH::Prog::InvIndex - base class for Swish-e inverted indexes

=head1 SYNOPSIS

 use SWISH::Prog::InvIndex;
 my $index = SWISH::Prog::InvIndex->new(path => 'path/to/index');
 print $index;  # prints $index->path
 my $meta = $index->meta;  # $meta isa SWISH::Prog::InvIndex::Meta object
 
=head1 DESCRIPTION

A SWISH::Prog::InvIndex is a base class for defining different Swish-e
inverted index formats.

=head1 METHODS

=head2 init

Implements the base SWISH::Prog::Class method.

=head2 path

Returns a Path::Class::Dir object representing the directory path to the index. 
The path is a directory which contains the various files that comprise the 
index.

=head2 meta

Returns a SWISH::Prog::InvIndex::Meta object with which you can query 
information about the index.

=head2 open

Open the invindex for reading/writing. Subclasses should implement this per
their IR library specifics.

This base open() method will rmtree( path() ) if clobber() is true,
and will mkpath() if path() does not exist. So SUPER::open() should
do something sane at minimum.

=head2 open_ro

Open the invindex in read-only mode. This is typical when searching
the invindex.

The default open_ro() method will simply call through to open().

=head2 close

Close the index. Subclasses should implement this per
their IR library specifics.

=head2 clobber

Get/set the boolean indicating whether the index should overwrite
any existing index with the same name. The default is true.

=head2 new_from_meta

Returns a new instance like new() does, blessed into the appropriate
class indicated by the C<swish.xml> meta header file.

=cut

1;

__END__


=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

