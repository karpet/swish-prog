#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 19;

use_ok('SWISH::Prog');
use_ok('SWISH::Prog::Native::Indexer');
use_ok('SWISH::Prog::Aggregator::FS');

#use_ok('SWISH::Prog::Config');
#use_ok('SWISH::Prog::Native::Searcher');

SKIP: {

    # is executable present?
    my $test = SWISH::Prog::Native::Indexer->new;
    if ( !$test->swish_check ) {
        skip "swish-e not installed", 6;
    }

    ok( my $invindex
            = SWISH::Prog::Native::InvIndex->new( path => 't/testindex', ),
        "new invindex"
    );

    ok( my $indexer = SWISH::Prog::Native::Indexer->new(
            invindex => $invindex,

            #config   => $config,
        ),
        "new indexer"
    );

    ok( my $aggregator = SWISH::Prog::Aggregator::FS->new(
            indexer => $indexer,

            #config  => $config,

            #verbose => 1,
            #debug   => 1,
        ),
        "new filesystem aggregator"
    );

    ok( my $prog = SWISH::Prog->new(
            aggregator => $aggregator,

            #verbose    => 1,
            #config => $config,
        ),
        "new program"
    );

    ok( $prog->run('t/test.html'), "index test.html" );

    is( $prog->count, 1, "indexed test docs" );

    # now create another index and merge the two.
    ok( my $invindex2
            = SWISH::Prog::Native::InvIndex->new( path => 't/testindex2', ),
        "new invindex2"
    );

    ok( my $indexer2
            = SWISH::Prog::Native::Indexer->new( invindex => $invindex2, ),
        "new indexer2"
    );

    # re-use our aggregator and program
    $aggregator->indexer($indexer2);
    ok( $prog->run('t/test2.html'), "index test2.html" );
    is( $prog->count, 1, "indexed 1 more doc" );

    # merge
    #$indexer->debug(1);
    ok( $indexer->merge($invindex2), "merge invindex2" );

    # add
    ok( my $doc = $aggregator->get_doc('t/test.xml'), "get doc" );
    ok( $indexer->add($doc), "add() doc" );

    # test with a search
SKIP: {

        eval { require SWISH::Prog::Native::Searcher; };
        if ($@) {
            skip "Cannot test Searcher without SWISH::API", 3;
        }
        ok( my $searcher = SWISH::Prog::Native::Searcher->new(
                invindex => $invindex,
                config   => $prog->config,
            ),
            "new searcher"
        );
        ok( my $results = $searcher->search('foo or words'), "do search" );
        is( $results->hits, 3, "3 hits" );

    }

    # clean up indexes
    $invindex->path->rmtree;
    $invindex2->path->rmtree;

}
