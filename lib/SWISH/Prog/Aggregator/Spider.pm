package SWISH::Prog::Aggregator::Spider;
use strict;
use warnings;
use base qw( SWISH::Prog::Aggregator );
use Carp;
use Scalar::Util qw( blessed );
use URI;
use HTTP::Cookies;
use SWISH::Prog::Utils;
use SWISH::Prog::Queue;
use SWISH::Prog::Cache;
use SWISH::Prog::Aggregator::Spider::UA;
use Search::Tools::UTF8;
use XML::Feed;

__PACKAGE__->mk_accessors(
    qw(
        agent
        authn_callback
        credential_timeout
        credentials
        delay
        email
        follow_redirects
        keep_alive
        link_tags
        max_depth
        max_files
        max_size
        max_time
        md5_cache
        queue
        remove_leading_dots
        same_hosts
        timeout
        ua
        uri_cache
        use_md5

        )
);

#use LWP::Debug qw(+);

our $VERSION = '0.67';

# TODO make these configurable
my %parser_types = %SWISH::Prog::Utils::ParserTypes;
my $default_ext  = $SWISH::Prog::Utils::ExtRE;
my $utils        = 'SWISH::Prog::Utils';

=pod

=head1 NAME

SWISH::Prog::Aggregator::Spider - web aggregator

=head1 SYNOPSIS

 use SWISH::Prog::Aggregator::Spider;
 my $spider = SWISH::Prog::Aggregator::Spider->new(
        indexer => SWISH::Prog::Indexer->new
 );
 
 $spider->indexer->start;
 $spider->crawl( 'http://swish-e.org/' );
 $spider->indexer->finish;

=head1 DESCRIPTION

SWISH::Prog::Aggregator::Spider is a web crawler similar to
the spider.pl script in the Swish-e 2.4 distribution. Internally,
SWISH::Prog::Aggregator::Spider uses LWP::RobotUA to the hard work.
See SWISH::Prog::Aggregator::Spider::UA.

=head1 METHODS

See SWISH::Prog::Aggregator

=head2 new( I<params> )

All I<params> have their own get/set methods too. They include:

=over

=item agent

Get/set the user-agent string reported by the user agent.

=item email

Get/set the email string reported by the user agent.

=item use_md5 

Flag as to whether each URI's content should be fingerprinted
and compared. Useful if the same content is available under multiple
URIs and you only want to index it once.

=item uri_cache 

Get/set the SWISH::Prog::Cache-derived object used to track which URIs have
been fetched already.

=item md5_cache 

If use_md5() is true, this SWISH::Prog::Cache-derived object tracks
the URI fingerprints.

=item queue 

Get/set the SWISH::Prog::Queue-derived object for tracking which URIs still
need to be fetched.

=item ua 

Get/set the SWISH::Prog::Aggregagor::Spider::UA object.

=item max_depth 

How many levels of links to follow. B<NOTE:> This value describes the number
of links from the first argument passed to I<crawl>.

Default is unlimited depth.

=item max_time

This optional key will set the max minutes to spider.   Spidering
for this host will stop after C<max_time> minutes, and move on to the
next server, if any.  The default is to not limit by time.

=item max_files

This optional key sets the max number of files to spider before aborting.
The default is to not limit by number of files.  This is the number of requests
made to the remote server, not the total number of files to index (see C<max_indexed>).
This count is displayted at the end of indexing as C<Unique URLs>.

This feature can (and perhaps should) be use when spidering a web site where dynamic
content may generate unique URLs to prevent run-away spidering.

=item max_size

This optional key sets the max size of a file read from the web server.
This B<defaults> to 5,000,000 bytes.  If the size is exceeded the resource is
truncated per LWP::UserAgent.

Set max_size to zero for unlimited size.

=item keep_alive

This optional parameter will enable keep alive requests.  This can dramatically speed
up spidering and reduce the load on server being spidered.  The default is to not use
keep alives, although enabling it will probably be the right thing to do.

To get the most out of keep alives, you may want to set up your web server to
allow a lot of requests per single connection (i.e MaxKeepAliveRequests on Apache).
Apache's default is 100, which should be good.

When a connection is not closed the spider does not wait the "delay"
time when making the next request.  In other words, there is no delay in
requesting documents while the connection is open.

Note: you must have at least libwww-perl-5.53_90 installed to use this feature.

=item delay

Get/set the number of seconds to wait between making requests. Default is
5 seconds (a very friendly delay).

=item timeout

Get/set the number of seconds to wait before considering the remote
server unresponsive. The default is 10.

=item authn_callback

CODE reference to fetch username/password credentials when necessary. See also
C<credentials>.

=item credential_timeout( I<n> )

Number of seconds to wait before skipping manual prompt for username/password.

=item credentials( I<user:pass> )

String with C<username>:C<password> pair to be used when prompted by 
the server.

=item follow_redirects( I<1|0> )

By default, 3xx responses from the server will be followed when
they are on the same hostname. Set to false (0) to not follow
redirects.

=item link_tags

TODO

=item remove_leading_dots

Microsoft server hack.

=item same_hosts( I<array> )

ARRAY ref of hostnames to be treated as identical to the original
host being spidered. By default the spider will not follow
links to different hosts.

=back

=head2 init

Initializes a new spider object. Called by new().

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    # defaults
    $self->{agent} ||= 'swish-prog-spider http://swish-e.org/';
    $self->{email} ||= 'swish@user.failed.to.set.email.invalid';
    $self->{use_cookies}      = 1 unless defined $self->{use_cookies};
    $self->{follow_redirects} = 1 unless defined $self->{follow_redirects};
    $self->{max_files}        = 0 unless defined( $self->{max_files} );
    $self->{max_size} ||= 5_000_000;
    $self->{max_depth} = undef unless defined( $self->{max_depth} );
    $self->{delay}     = 5     unless defined $self->{delay};
    croak "delay must be expressed in seconds" if $self->{delay} =~ m/\D/;

    $self->{credential_timeout} = 30
        unless exists $self->{credential_timeout};
    croak "credential_timeout must be a number"
        if defined $self->{credential_timeout}
        and $self->{credential_timeout} =~ m/\D/;

    $self->{queue}     ||= SWISH::Prog::Queue->new;
    $self->{uri_cache} ||= SWISH::Prog::Cache->new;
    $self->{_uri_ok_cache} = SWISH::Prog::Cache->new;
    $self->{_auth_cache}   = SWISH::Prog::Cache->new;  # ALWAYS inmemory cache
    $self->{ua} ||= SWISH::Prog::Aggregator::Spider::UA->new( $self->{agent},
        $self->{email}, );

    $self->{link_tags} = ['a'] unless ref $self->{link_tags} eq 'ARRAY';
    $self->{link_tags_lookup}
        = { map { lc($_) => 1 } @{ $self->{link_tags} } };

    $self->{timeout} = 10 unless defined $self->{timeout};
    croak "timeout must be a number" if $self->{timeout} =~ m/\D/;

    # we handle our own delay
    $self->{ua}->delay(0);

    $self->{ua}->timeout( $self->{timeout} );
    $self->{ua}->max_size( $self->{max_size} );
    $self->{ua}->max_redirect(0);    # we manage this

    if ( $self->{use_cookies} ) {
        $self->{ua}->cookie_jar( HTTP::Cookies->new() );
    }
    if ( $self->{keep_alive} ) {
        if ( $self->{ua}->can('conn_cache') ) {
            my $keep_alive
                = $self->{keep_alive} =~ m/^\d+$/
                ? $self->{keep_alive}
                : 1;
            $self->{ua}->conn_cache( { total_capacity => $keep_alive } );
        }
        else {
            warn
                "can't use keep-alive: conn_cache() method not available on ua "
                . ref( $self->{ua} );
        }
    }

    $self->{_current_depth} = 1;

    $self->{same_hosts} ||= [];
    $self->{same_host_lookup} = { map { $_ => 1 } @{ $self->{same_hosts} } };

    if ( $self->{use_md5} ) {
        eval "require Digest::MD5" or croak $@;
        $self->{md5_cache} ||= SWISH::Prog::Cache->new;
    }

    # from spider.pl. not sure if we need it or not.
    # Lame Microsoft
    $URI::ABS_REMOTE_LEADING_DOTS = $self->{remove_leading_dots} ? 1 : 0;

    return $self;
}

=head2 uri_ok( I<uri> )

Returns true if I<uri> is acceptable for including in an index.
The 'ok-ness' of the I<uri> is based on its base, robot rules,
and the spider configuration.

=cut

sub uri_ok {
    my $self = shift;
    my $uri  = shift or croak "URI required";
    my $str  = $uri->canonical->as_string;
    $str =~ s/#.*//;    # target anchors create noise
    return 0 if $self->{_uri_ok_cache}->has($str);
    $self->{_uri_ok_cache}->add($str);

    ( $self->verbose > 1 ) and warn "checking uri_ok: $str\n";

    # check if we're on the same host.
    if ( $uri->rel( $self->{_base} ) eq $uri ) {

        # not on this host. check our aliases
        if ( !exists $self->{same_host_lookup}
            ->{ $uri->canonical->authority || '' } )
        {
            my $host = $uri->canonical->authority;
            $self->debug
                and warn "$uri [skipping, not on same host as $host]\n";
            return 0;
        }

        # in same host lookup, so proceed.
    }

    my $path = $uri->path;
    my $mime = $utils->mime_type($path);

    if ( !exists $parser_types{$mime} ) {

        $self->debug and warn "no parser for $mime";
        return 0;
    }

    # TODO
    # check regex

    return 1;
}

sub _add_links {
    my ( $self, $parent, @links ) = @_;

    # calc depth
    if ( !$self->{_parent} || $self->{_parent} ne $parent ) {
        $self->{_current_depth}++;
    }

    $self->{_parent} ||= $parent;    # first time.

    for my $l (@links) {
        my $uri = $l->abs( $self->{_base} ) or next;
        my $uri_str = $uri;
        $uri_str =~ s/#.*//;         # target anchors create noise
        next if $self->uri_cache->has($uri_str);    # check only once
        $self->uri_cache->add( $uri_str => $self->{_current_depth} );

        if ( $self->uri_ok($uri) ) {
            $self->queue->put($uri);
        }
    }
}

# ported from spider.pl
# Do we need to authorize?  If so, ask for password and request again.
# First we try using any cached value
# Then we try using the get_password callback
# Then we ask.

sub _authorize {
    my ( $self, $uri, $response ) = @_;

    delete $self->{last_auth};    # since we know that doesn't work

    if (   $response->header('WWW-Authenticate')
        && $response->header('WWW-Authenticate') =~ /realm="([^"]+)"/i )
    {
        my $realm = $1;
        my $user_pass;

        # Do we have a cached user/pass for this realm?
        # only each URI only once
        unless ( $self->{_request}->{auth}->{$uri}++ ) {
            my $key = $uri->canonical->host_port . ':' . $realm;

            if ( $user_pass = $self->{_auth_cache}->get($key) ) {

                # If we didn't just try it, try again
                unless ( $uri->userinfo && $user_pass eq $uri->userinfo ) {

                    # add the user/pass to the URI
                    $uri->userinfo($user_pass);
                    warn " >> set userinfo via _auth_cache\n" if $self->debug;
                    return 1;
                }
                else {
                    # we've tried this before
                    warn "tried $user_pass before";
                    return 0;
                }
            }
        }

        # now check for a callback password (if $user_pass not set)
        unless ( $user_pass || $self->{_request}->{auth}->{callback}++ ) {

            # Check for a callback function
            if ( $self->{authn_callback}
                and ref $self->{authn_callback} eq 'CODE' )
            {
                $user_pass = $self->{authn_callback}
                    ->( $self, $uri, $response, $realm );
                $uri->userinfo($user_pass);
                warn " >> set userinfo via authn_callback\n" if $self->debug;
                return 1;
            }
        }

        # otherwise, prompt (over and over)
        if ( !$user_pass ) {
            $user_pass = $self->_get_basic_credentials( $uri, $realm );
        }

        if ($user_pass) {
            $uri->userinfo($user_pass);
            $self->{cur_realm} = $realm;  # save so we can cache if it's valid
            return 1;
        }
    }

    return 0;

}

# From spider.pl
sub _get_basic_credentials {
    my ( $self, $uri, $realm ) = @_;

    # Exists but undefined means don't ask.
    return
        if exists $self->{credential_timeout}
        && !defined $self->{credential_timeout};

    my $netloc = $uri->canonical->host_port;

    my ( $user, $password );

    eval {
        local $SIG{ALRM} = sub { die "timed out\n" };

        # a zero timeout means don't time out
        alarm( $self->{credential_timeout} ) unless $^O =~ /Win32/i;

        if ( $uri->userinfo ) {
            print STDERR "\nSorry: invalid username/password\n";
            $uri->userinfo(undef);
        }

        print STDERR
            "Need Authentication for $uri at realm '$realm'\n(<Enter> skips)\nUsername: ";
        $user = <STDIN>;
        chomp($user) if $user;
        die "No Username specified\n" unless length $user;

        alarm( $self->{credential_timeout} ) unless $^O =~ /Win32/i;

        print STDERR "Password: ";
        system("stty -echo");
        $password = <STDIN>;
        system("stty echo");
        print STDERR "\n";    # because we disabled echo
        chomp($password);
        alarm(0) unless $^O =~ /Win32/i;
    };

    alarm(0) unless $^O =~ /Win32/i;

    return if $@;

    return join ':', $user, $password;

}

=head2 get_doc

Returns the next URI from the queue() as a SWISH::Prog::Doc object,
or the error message if there was one.

Returns undef if the queue is empty or max_depth() has been reached.

=cut

sub get_doc {
    my $self = shift;

    # return unless we have something in the queue
    return unless $self->queue->size;

    # pop the queue and make it a URI
    my $uri   = $self->queue->get;
    my $depth = $self->uri_cache->get($uri);

    $self->debug
        and warn sprintf( "%s [depth:%d max_depth:%s]\n",
        $uri, $depth, ( $self->max_depth || 'undef' ) );

    return if defined $self->max_depth && $depth > $self->max_depth;

    $self->{_cur_depth} = $depth;

    my $doc = $self->_make_request($uri);

    if ($doc) {
        $self->queue->remove($uri);
    }

    return $doc;
}

=head2 get_authorized_doc( I<uri>, I<response> )

Called internally when the server returns a 401 or 403 response.
Will attempt to determine the correct credentials for I<uri>
based on the previous attempt in I<response> and what you 
have configured in B<credentials>, B<authn_callback> or when
manually prompted.

=cut

sub get_authorized_doc {
    my $self     = shift;
    my $uri      = shift or croak "uri required";
    my $response = shift or croak "response required";

    # set up credentials
    $self->_authorize( $uri, $response ) or return;

    return $self->_make_request($uri);
}

sub _make_request {
    my ( $self, $uri ) = @_;

    # get our useragent
    my $ua    = $self->ua;
    my $delay = 0;
    if ( $self->{keep_alive} ) {
        $delay = 0;
    }
    elsif ( !$self->{delay} or !$self->{_last_response_time} ) {
        $delay = 0;
    }
    else {
        my $elapsed = time() - $self->{_last_response_time};
        $delay = $self->{delay} - $elapsed;
        $delay = 0 if $delay < 0;
        warn " elapsed:$elapsed delay:$delay\n" if $self->debug;
    }

    warn "get $uri [delay:$delay]\n" if $self->verbose;

    # Set basic auth if defined - use URI specific first, then credentials.
    # this doesn't track what should have authorization
    my $last_auth;
    if ( $self->{last_auth} ) {
        my $path = $uri->path;
        $path =~ s!/[^/]*$!!;
        $last_auth = $self->{last_auth}->{auth}
            if $self->{last_auth}->{path} eq $path;
    }

    my %get_args = (
        uri   => $uri,
        delay => $delay,
    );

    if ( my ( $user, $pass ) = split /:/,
        ( $last_auth || $uri->userinfo || $self->{credentials} || '' ) )
    {
        $get_args{user} = $user;
        $get_args{pass} = $pass;
    }

    # fetch the uri. $ua handles delay internally.
    my $response = $ua->get(%get_args);

    # flag current time for next delay calc.
    $self->{_last_response_time} = time();

    # redirect? follow, conditionally.
    if ( $response->is_redirect ) {
        my $location = $response->header('location');
        if ( !$location ) {
            warn "Redirect without a Location header";
            return $response->code;
        }
        $self->debug
            and warn "redirect: $location\n";
        if ( $self->follow_redirects ) {
            $self->_add_links( $uri,
                URI->new_abs( $location, $response->base ) );
        }
        return $response->code;
    }

    # add its links to the queue.
    # If the resource looks like an XML feed of some kind,
    # glean its links differently than if it is an HTML response.
    if ( my $feed = $self->looks_like_feed($response) ) {
        my @links;
        for my $entry ( $feed->entries ) {
            push @links, URI->new( $entry->link );
        }
        $self->_add_links( $uri, @links );

        # we don't want the feed content, we want the links.
        # TODO make this optional
        return $response->code;
    }
    else {
        $self->_add_links( $uri, $ua->links );
    }

    # return $uri as a Doc object
    my $use_uri = $ua->success ? $ua->uri : $uri;
    my $meta = {
        org_uri => $uri,
        ret_uri => ( $use_uri || $uri ),
        depth   => delete $self->{_cur_depth},
        status  => $ua->status,
        success => $ua->success,
        is_html => $ua->is_html,
        title   => (
            $ua->success
            ? ( $ua->is_html
                ? ( $ua->title || "No title: $use_uri" )
                : $use_uri
                )
            : "Failed: $use_uri"
        ),
        ct => ( $ua->success ? $ua->ct : "Unknown" ),
    };

    my $headers = $response->headers;
    my $buf     = $response->content;

    if ( $self->{use_md5} ) {
        my $fingerprint = $response->header('Content-MD5')
            || Digest::MD5::md5($buf);
        if ( $self->md5_cache->has($fingerprint) ) {
            return "duplicate content for "
                . $self->md5_cache->get($fingerprint);
        }
        $self->md5_cache->add( $fingerprint => $uri );
    }

    if ( $ua->success ) {

        my $content_type = $meta->{ct};
        if ( !exists $parser_types{$content_type} ) {
            warn "no parser for $content_type";
        }
        my $charset = $headers->content_type;
        $charset =~ s/;?$meta->{ct};?//;
        my $encoding = $headers->content_encoding || $charset;
        my %doc = (
            url     => $meta->{org_uri},
            modtime => ( $headers->last_modified || $headers->date ),
            type    => $meta->{ct},
            content => ( $encoding =~ m/utf-8/i ? to_utf8($buf) : $buf ),
            size => $headers->content_length || length( pack 'C0a*', $buf ),
            charset => $encoding,
        );

        # cache whatever credentials were used so we can re-use
        if ( $self->{cur_realm} and $uri->userinfo ) {
            my $key = $uri->canonical->host_port . ':' . $self->{cur_realm};
            $self->{_auth_cache}->add( $key => $uri->userinfo );

            # not too sure of the best logic here
            my $path = $uri->path;
            $path =~ s!/[^/]*$!!;
            $self->{last_auth} = {
                path => $path,
                auth => $uri->userinfo,
            };
        }

        # return doc
        return $self->doc_class->new(%doc);

    }
    elsif ( $response->code == 401 ) {

        # authorize and try again
        warn sprintf( "%s : %s\n", $uri, $response->status_line );
        return $self->get_authorized_doc( $uri, $response )
            || $response->code;
    }
    else {

        warn sprintf( "%s : %s\n", $uri, $response->status_line );
        return $response->code;
    }

    return;    # never get here.
}

=head2 looks_like_feed( I<http_response> )

Called internally to perform naive heuristics on I<http_response>
to determine whether it looks like an XML feed of some kind,
rather than a HTML page.

=cut

sub looks_like_feed {
    my $self     = shift;
    my $response = shift or croak "response required";
    my $headers  = $response->headers;
    my $ct       = $headers->content_type;
    if ( $ct eq 'text/html' or $ct eq 'application/xhtml+xml' ) {
        return 0;
    }
    if (   $ct eq 'text/xml'
        or $ct eq 'application/rss+xml'
        or $ct eq 'application/rdf+xml'
        or $ct eq 'application/atom+xml' )
    {
        my $xml = $response->content;
        return XML::Feed->parse( \$xml );
    }

    return 0;
}

=head2 crawl( I<uri> )

Implements the required crawl() method. Recursively fetches I<uri>
and its child links to a depth set in max_depth(). Will quit
after max_files() unless max_files==0.

=cut

sub crawl {
    my $self = shift;
    my @urls = @_;

    my $indexer = $self->indexer;

    my $started = time();

    for my $url (@urls) {
        $self->debug and warn "crawling $url\n";
        my $uri = URI->new($url);
        $self->uri_cache->add( $uri => 1 );
        $self->queue->put($uri);
        $self->{_base} = $uri->canonical->as_string;
        while ( my $doc = $self->get_doc ) {
            $self->debug and warn '=' x 80, "\n";
            next unless blessed($doc);
            $indexer->process($doc);
            $self->_increment_count;
            last if $self->max_files and $self->count >= $self->max_files;
            last
                if $self->max_time
                and ( time() - $started ) > $self->max_time;
        }
    }

    return $self->count;
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
