#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 4;
use HTTP::Date;

my $num_tests = 4;

SKIP: {

    eval "use SWISH::Prog::Aggregator::Spider";
    if ( $@ && $@ =~ m/([\w:]+)/ ) {
        skip "$1 required for spider test: $@", $num_tests;
    }

    eval "use Test::HTTP::Server::Simple";
    if ($@) {
        skip "Test::HTTP::Server::Simple required for spider-server test: $@",
            $num_tests;
    }

    eval "use HTTP::Server::Simple::CGI";
    if ($@) {
        skip "HTTP::Server::Simple::CGI required for spider-server test: $@",
            $num_tests;
    }

    eval "use HTTP::Server::Simple::Authen";
    if ($@) {
        skip
            "HTTP::Server::Simple::Authen required for spider-server test: $@",
            $num_tests;
    }

    # define our test server
    {

        package MyAuth;
        use strict;

        sub new { return bless {} }

        sub authenticate {
            my ( $self, $user, $pass ) = @_;
            return $user eq 'foo' && $pass eq 'bar';
        }

        package MyServer;
        use Data::Dump qw( dump );
        use HTTP::Date;
        @MyServer::ISA = ( 'Test::HTTP::Server::Simple',
            'HTTP::Server::Simple::Authen',
            'HTTP::Server::Simple::CGI' );

        my %dispatch = (
            '/'                  => \&resp_root,
            '/hello'             => \&resp_hello,
            '/robots.txt'        => \&resp_robots,
            '/secret'            => { code => \&resp_secret },
            '/secret/more'       => \&resp_hello,
            '/redirect/local'    => [ 307, '/target' ],
            '/redirect/loopback' => [ 307, 'http://127.0.0.1/hello' ],
            '/old/page'          => \&resp_old_page,
            '/size/big'          => \&resp_big_page,
            '/img/test'          => \&resp_img,
            '/redirect/elsewhere' =>
                [ 307, 'http://somewherefaraway.net/donotfollow' ],
        );

        sub handle_request {
            my ( $self, $cgi ) = @_;

            #dump \%ENV;
            my $path = $cgi->path_info();

            #warn "path=$path";

            my $handler = $dispatch{$path};
            if ( ref $handler eq 'CODE' ) {
                print "HTTP/1.0 200 OK\r\n";
                $handler->($cgi);

            }
            elsif ( ref $handler eq 'ARRAY' ) {
                print "HTTP/1.0 $handler->[0]\r\n";
                print "Location: $handler->[1]\r\n";
            }
            elsif ( ref $handler eq 'HASH' ) {
                $handler->{code}->( $self, $cgi, $handler );
            }
            else {
                print "HTTP/1.0 404 Not found\r\n";
                print $cgi->header,
                    $cgi->start_html('Not found'),
                    $cgi->h1('Not found'),
                    $cgi->end_html;
            }

        }

        sub resp_root {
            my $cgi = shift;
            print $cgi->header, $cgi->start_html,
                qq(<a href="#">recursive anchor</a>),
                qq(<a href="/">root</a>),
                qq(<a href="hello">follow me</a>),
                qq(<a href="secret">secret</a>),
                qq(<a href="nosuchlink">404</a>),
                qq(<a href="far/too/deep/to/reach">depth</a>),
                qq(<a href="http://somewhereelse.net/donotfollow">external link</a>),
                qq(<a href="redirect/local">redirect local</a>),
                qq(<a href="redirect/loopback">redirect loopback</a>),
                qq(<a href="redirect/elsewhere">redirect elsewhere</a>),
                qq(<a href="old/page">old and in the way</a>),
                qq(<a href="size/big">big file</a>),
                qq(<a href="skip-me/bad-pattern">FileRules skip</a>),
                qq(<a href="skip-me/bad?query=pass">FileRules skip</a>),
                qq(<img src="img/test" />),
                $cgi->end_html;
        }

        sub resp_big_page {
            my $cgi = shift;
            print "Content-Length: 8192\r\n";
            print $cgi->header;
            print 'i am a really big file';

        }

        sub resp_img {
            my $cgi = shift;
            print $cgi->header('image/jpeg');
            print 'thisisanimage.heh';
        }

        sub resp_old_page {
            my $cgi = shift;
            printf( "Last-Modified: %s\r\n", time2str( time() - 86400 ) )
                ;    # yesterday
            print $cgi->header, $cgi->start_html, 'this page is old',
                $cgi->end_html;
        }

        sub resp_hello {
            my $cgi = shift;
            return if !ref $cgi;
            print $cgi->header, $cgi->h1('hello');
        }

        sub resp_robots {
            my $cgi = shift;
            print $cgi->header('text/plain'), '';    # TODO
        }

        sub authen_handler {
            return MyAuth->new();
        }

        sub resp_secret {
            my $self    = shift;
            my $cgi     = shift;
            my $handler = shift;

            if ( !$self->authenticate ) {
                print $cgi->header;
                print 'permission denied';
            }
            else {
                print "HTTP/1.0 200 OK\r\n";
                print $cgi->header, $cgi->start_html,
                    qq(<a href="secret/more">more secret</a>),
                    $cgi->end_html;
            }
        }
    }

    use_ok('SWISH::Prog::Test::Indexer');

    my $server   = MyServer->new();
    my $base_uri = $server->started_ok('start http server');
    my $debug    = $ENV{PERL_DEBUG};

    ok( my $spider = SWISH::Prog::Aggregator::Spider->new(
            verbose => $debug,
            debug   => $debug,
            email   => 'noone@swish-e.org',
            agent   => 'swish-prog-test',

            #max_depth => 2, # unlimited

            file_rules => [
                'filename contains bad-pattern',

                #'filename contains \?',    # anything with query string
                'filename contains \?.*query=pass',    # specific query param
            ],

            # hurry up and fail
            delay => 0,

            filter => sub {
                $debug and diag( "doc filter on " . $_[0]->url );
                $debug and diag( "body:" . $_[0]->content );
            },
            credentials    => 'foo:bar',
            same_hosts     => ["127.0.0.1"],
            modified_since => time2str( time() ),
            max_size       => 4096,
        ),
        "new spider"
    );

    diag( "spidering " . $base_uri );
    is( $spider->crawl($base_uri), 4, "crawl" );

}
