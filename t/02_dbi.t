use strict;
use warnings;
use Test::More tests => 5;

use Carp;
use Data::Dump qw( dump );

use_ok('SWISH::Prog::Native::Indexer');

# we use Rose::DBx::TestDB just for devel testing.
# don't expect normal users to have it.
SKIP: {
    eval "use SWISH::Prog::Aggregator::DBI";
    if ($@) {
        skip "DBI tests require DBI", 4;
    }

    eval "use Rose::DBx::TestDB";
    if ($@) {
        diag "install Rose::DBx::TestDB to test the DBI aggregator";
        skip "Rose::DBx::TestDB not installed", 4;
    }

    # is executable present?
    my $indexer = SWISH::Prog::Native::Indexer->new;
    if ( !$indexer->swish_check ) {
        skip "swish-e not installed", 4;
    }

    # create db.
    my $db = Rose::DBx::TestDB->new;

    my $dbh = $db->retain_dbh;

    # put some data in it.
    $dbh->do( "
    CREATE TABLE foo (
        id      integer primary key autoincrement,
        myint   integer not null default 0,
        mychar  varchar(16),
        mydate  integer not null default 1
    );
    " )
        or croak "create failed: " . $dbh->errstr;

    $dbh->do( "
        INSERT INTO foo (myint, mychar, mydate) VALUES (100, 'hello', 1000000);
    " ) or croak "insert failed: " . $dbh->errstr;

    my $sth = $dbh->prepare("SELECT * from foo");
    $sth->execute;

    # index it
    ok( my $aggr = SWISH::Prog::Aggregator::DBI->new(
            db      => $dbh,
            indexer => SWISH::Prog::Native::Indexer->new(
                invindex => 't/dbi_index',
            ),
            schema => {
                foo => {
                    id     => { type => 'int' },
                    myint  => { type => 'int', bias => 10 },
                    mychar => { type => 'char' },
                    mydate => { type => 'date' },
                }
            },
        ),
        "new aggregator"
    );

    ok( $aggr->indexer->start, "indexer started" );

    is( $aggr->crawl(), 1, "row data indexed" );

    ok( $aggr->indexer->finish, "indexer finished" );

    # clean up header so other test counts work
    unlink('t/dbi_index/swish.xml') unless $ENV{PERL_DEBUG};

}
