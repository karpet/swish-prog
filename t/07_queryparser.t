use Test::More tests => 3;

use_ok('SWISH::Prog::QueryParser');
use_ok('SWISH::Prog::Config');

my %str = (

    'foo bar'               => '',
    'bar or foo'            => '',
    '"foo bar"~10'          => '',
    'foo not bar'           => '',
    'title:foo or body:bar' => '',
    '(foo AND bar) or quz'  => '',

);

ok( my $parser = SWISH::Prog::QueryParser->new(
        config => SWISH::Prog::Config->new(),

    ),
    "parser"
);

for my $s ( sort keys %str ) {
    my $q = $parser->parse($s);
    diag("$s  ->  $q");

    #diag( $q->dump );

}

