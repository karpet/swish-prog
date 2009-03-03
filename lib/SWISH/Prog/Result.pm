package SWISH::Prog::Result;
use strict;
use warnings;
use base qw( SWISH::Prog::Class );
use Carp;

our $VERSION = '0.27_01';

__PACKAGE__->mk_accessors(qw( doc score ));

=head1 NAME

SWISH::Prog::Result - base result class

=head1 SYNOPSIS
                
 my $results = $searcher->search( 'foo bar' );
 while (my $result = $results->next) {
     printf("%4d %s\n", $result->score, $result->uri);
 }

=head1 DESCRIPTION

SWISH::Prog::Results is a base results class. It defines
the APIs that all SWISH::Prog storage backends adhere to in
returning results from a SWISH::Prog::InvIndex.

=head1 METHODS

The following methods are all accessors (getters) only.

=head2 uri

=head2 mtime

=head2 title

=head2 summary

=head2 swishdocpath

Alias for uri().

=head2 swishlastmodified

Alias for mtime().

=head2 swishtitle

Alias for title().

=head2 swishdescription

Alias for summary().

=cut

sub uri     { croak "must implement uri" }
sub mtime   { croak "must implement mtime" }
sub title   { croak "must implement title" }
sub summary { croak "must implement summary" }

# version 2 names for the faithful
*swishdocpath      = \&uri;
*swishlastmodified = \&mtime;
*swishtitle        = \&title;
*swishdescription  = \&summary;

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

