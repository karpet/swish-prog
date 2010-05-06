use strict;
use warnings;
use Test::More tests => 17;

use_ok('SWISH::Prog');
use_ok('SWISH::Prog::Native::Indexer');
use_ok('SWISH::Prog::Aggregator::FS');
use_ok('SWISH::Prog::Config');

SKIP: {

    # is executable present?
    my $test = SWISH::Prog::Native::Indexer->new;
    if ( !$test->swish_check ) {
        skip "swish-e not installed", 13;
    }

    ok( my $config = SWISH::Prog::Config->new('t/test.conf'),
        "config from t/test.conf" );

    # skip our local config test files
    $config->FileRules('dirname contains config');
    $config->FileRules( 'filename is swish.xml', 1 );

    ok( my $invindex
            = SWISH::Prog::Native::InvIndex->new( path => 't/testindex', ),
        "new invindex"
    );

    ok( my $indexer = SWISH::Prog::Native::Indexer->new(
            invindex => $invindex,
            config   => $config,
        ),
        "new indexer"
    );

    ok( my $aggregator = SWISH::Prog::Aggregator::FS->new(
            indexer => $indexer,
            config  => $config,

            #verbose => 1,
            #debug   => 1,
        ),
        "new filesystem aggregator"
    );

    ok( my $prog = SWISH::Prog->new(
            aggregator => $aggregator,

            #verbose    => 1,
            config => $config,
        ),
        "new program"
    );

    ok( $prog->run('t/'), "run program" );

    is( $prog->count, 6, "indexed test docs" );

    # test with a search
SKIP: {

        eval { require SWISH::Prog::Native::Searcher; };
        if ($@) {
            skip "Cannot test Searcher without SWISH::API", 6;
        }
        ok( my $searcher
                = SWISH::Prog::Native::Searcher->new( invindex => $invindex,
                ),
            "new searcher"
        );
        ok( my $results = $searcher->search('gzip-special'), "do search" );
        is( $results->hits, 1, "1 hit" );
        ok( my $result = $results->next, "results->next" );
        is( $result->swishtitle, 'test gzip html doc', "get swishtitle" );
        is( $result->get_property('swishtitle'),
            $result->swishtitle, "get_property(swishtitle)" );

    }

    # clean up header so other test counts work
    unlink('t/testindex/swish.xml') unless $ENV{PERL_DEBUG};

}
