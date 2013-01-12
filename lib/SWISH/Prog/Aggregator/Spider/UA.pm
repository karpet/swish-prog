package SWISH::Prog::Aggregator::Spider::UA;
use strict;
use warnings;
use base qw( LWP::RobotUA );
use HTTP::Message;
use HTML::LinkExtor;
use URI;
use HTML::Tagset;
use HTML::HeadParser;
use Carp;
use Data::Dump qw( dump );
use Search::Tools::UTF8;

=pod

=head1 NAME

SWISH::Prog::Aggregator::Spider::UA - spider user agent

=head1 SYNOPSIS

 use SWISH::Prog::Aggregator::Spider::UA;
 my $ua = SWISH::Prog::Aggregator::Spider::UA->new;
 
 # $ua is a LWP::RobotUA object

=head1 DESCRIPTION

SWISH::Prog::Aggregator::Spider::UA is a subclass of 
LWP::RobotUA.

=head1 METHODS

=head2 get( I<uri>, I<delay> )

sleep() I<delay> seconds before fetching I<uri>.

=cut

my $can_accept = HTTP::Message::decodable;

our $Debug = 0;

sub get {
    my $self = shift;
    my $uri  = shift or croak "URI required";
    my $resp = $self->SUPER::get( $uri, 'Accept-Encoding' => $can_accept, );
    $self->{_swish_last_uri}  = URI->new($uri);
    $self->{_swish_last_resp} = $resp;
    return $resp;
}

=head2 response

Returns most recent HTTP::Response object.

=cut

sub response {
    my $self = shift;
    return $self->{_swish_last_resp};
}

=head2 success

Shortcut for $ua->response->is_success.

=cut

sub success {
    return shift->response->is_success;
}

=head2 uri

Returns most recently requested URI object.

=cut

sub uri {
    return shift->{_swish_last_uri};
}

=head2 status

Shortcut for $ua->response->code.

=cut

sub status {
    return shift->response->code;
}

=head2 ct

Shortcut for $ua->response->header('content-type').

=cut

sub ct {
    return shift->response->header('content-type');
}

=head2 is_html

Returns true if ct() looks like HTML or XHTML.

=cut

sub is_html {
    my $self = shift;
    my $ct   = $self->ct;
    return defined $ct
        && ( $ct eq 'text/html' || $ct eq 'application/xhtml+xml' );
}

=head2 content

Shortcut for $ua->response->decoded_content.

=cut

sub content {
    return shift->response->decoded_content;
}

=head2 links

Returns array of href targets in content(). Parsed
using HTML::LinkExtor.

=cut

sub links {
    my $self     = shift;
    my $response = $self->response;
    my @links    = ();
    if ($response) {
        my $le = HTML::LinkExtor->new();
        $le->parse( $response->decoded_content );

        my %skipped_tags;

        for my $link ( $le->links ) {
            my ( $tag, %attr ) = @$link;

            # which tags to use ( not reported in debug )

            my $attr = join ' ', map {qq[$_="$attr{$_}"]} keys %attr;

            warn "\nLooking at extracted tag '<$tag $attr>'\n"
                if $Debug;

            # Grab which attribute(s) which might contain links for this tag
            my $links = $HTML::Tagset::linkElements{$tag};
            $links = [$links] unless ref $links;

            my $found;

            # Now, check each attribut to see if a link exists

            for my $attribute (@$links) {
                if ( $attr{$attribute} ) {
                    my $u
                        = URI->new_abs( $attr{$attribute}, $response->base );

                    push @links, $u;
                    warn
                        qq[   $attribute="$u" Added to list of links to follow\n]
                        if $Debug;
                    $found++;
                }
            }

            if ( !$found && $Debug ) {
                warn
                    "  tag did not include any links to follow or is a duplicate\n";
            }

        }

        warn "! Found ", scalar @links, " links in ", $response->base, "\n\n"
            if $Debug;

    }
    return @links;
}

=head2 title

Returns document title, verifying that UTF-8
flag is set correctly on the response content.

=cut

sub title {
    my $self = shift;
    return unless $self->is_html;

    my $p = HTML::HeadParser->new;

    # HTML::HeadParser throws warning if utf-8 flag is not on for utf-8 bytes.
    # So we trust the content-type header and
    # verify that the utf-8 flag is on.
    if ( $self->response->header('content-type') =~ m/utf-8/i ) {
        $p->parse( to_utf8( $self->content ) );
    }
    else {
        $p->parse( $self->content );
    }
    return $p->header('Title');
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
