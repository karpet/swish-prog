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

=head2 get( I<args> )

I<args> is an array of key/value pairs. I<uri> is required.

I<delay> will sleep() I<delay> seconds before fetching I<uri>.

Also supported: I<user> and I<pass> for authorization.

=cut

# if Compress::Zlib is installed, this should handle gzip transparently.
# thanks to
# http://stackoverflow.com/questions/1285305/how-can-i-accept-gzip-compressed-content-using-lwpuseragent
my $can_accept = HTTP::Message::decodable();

#warn "Accept-Encoding: $can_accept\n";

our $Debug = $ENV{PERL_DEBUG} || 0;

sub set_link_tags {
    my $self = shift;
    $self->{_swish_link_tags} = shift;
}

sub get {
    my $self  = shift;
    my %args  = @_;
    my $uri   = $args{uri} or croak "URI required";
    my $delay = $args{delay} || 0;

    sleep($delay) if $delay;

    my $request = HTTP::Request->new( 'GET' => $uri );
    $request->header( 'Accept-Encoding' => $can_accept, );
    if ( $args{user} and $args{pass} ) {
        $request->authorization_basic( $args{user}, $args{pass} );
    }

    ( $Debug & 2 ) and dump $request;

    my $resp = $self->request($request);
    $self->{_swish_last_uri}  = URI->new($uri);
    $self->{_swish_last_resp} = $resp;

    ( $Debug & 2 ) and dump $resp;

    return $resp;
}

sub head {
    my $self  = shift;
    my %args  = @_;
    my $uri   = $args{uri} or croak "URI required";
    my $delay = $args{delay} || 0;

    sleep($delay) if $delay;

    my $request = HTTP::Request->new( 'HEAD' => $uri );
    $request->header( 'Accept-Encoding' => $can_accept, );
    if ( $args{user} and $args{pass} ) {
        $request->authorization_basic( $args{user}, $args{pass} );
    }

    ( $Debug & 2 ) and dump $request;

    my $resp = $self->request($request);

    ( $Debug & 2 ) and dump $resp;

    return $resp;
}

sub redirect_ok {
    return 0;    # do not follow any redirects
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
    my $self = shift;
    my $ct   = $self->response->header('content-type');
    $ct =~ s/;.+// if $ct;
    return $ct;
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
    my $self  = shift;
    my @links = ();
    if ( $self->response and $self->is_html ) {
        my $le   = HTML::LinkExtor->new();
        my $base = $self->response->base;
        $le->parse( $self->content );

        my %skipped_tags;

        for my $link ( $le->links ) {
            my ( $tag, %attr ) = @$link;

            # which tags to use
            my $attr = join ' ', map {qq[$_="$attr{$_}"]} keys %attr;

            $Debug and warn "$base [extracted tag '<$tag $attr>']\n";

            if ( !exists $self->{_swish_link_tags}->{$tag} ) {
                $Debug
                    and warn
                    "$base [skipping tag '<$tag $attr>', not on whitelist]\n";
                next;
            }

            # Grab which attribute(s) which might contain links for this tag
            my $links = $HTML::Tagset::linkElements{$tag};
            $links = [$links] unless ref $links;

            my $found = 0;

            # check each attribute to see if a link exists
            for my $attribute (@$links) {
                if ( $attr{$attribute} ) {

                    # strip any anchors as noise
                    $attr{$attribute} =~ s/#.*//;

                    my $u = URI->new_abs( $attr{$attribute}, $base );
                    push @links, $u;
                    $Debug
                        and warn
                        sprintf( "%s [added '%s' to links]\n", $base, $u );
                    $found++;
                }
            }

            if ( !$found && $Debug ) {
                warn
                    "$base [tag <$tag $attr> has no links or is a duplicate]\n";
            }

        }

        $Debug
            and warn sprintf( "%s [found %s links]\n", $base, scalar @links );

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
