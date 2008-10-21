package SWISH::Prog::Query;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;

our $VERSION = '0.21';

__PACKAGE__->mk_ro_accessors(qw( q parser ));

use overload(
    '""'     => \&stringify,
    fallback => 1,
);

sub stringify {
    my $self = shift;
    return $self->parser->unparse( $self->q );
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

