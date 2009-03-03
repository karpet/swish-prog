use strict;
use warnings;
use Test::More tests => 3;

use_ok('SWISH::Prog::QueryParser');
use_ok('SWISH::Prog::Config');

my %str = (

    'foo bar'                            => '',
    'bar or foo'                         => '',
    '"foo bar"~10'                       => '',
    'foo not bar'                        => '',
    'swishtitle:foo or swishdefault:bar' => '',
    '(foo AND bar) or quz'               => '',
    'adobe -photoshop'                   => '',

);

ok( my $parser = SWISH::Prog::QueryParser->new(
        config => SWISH::Prog::Config->new(),

    ),
    "parser"
);

for my $s ( sort keys %str ) {
    my $q = $parser->parse($s);
    diag( sprintf( "%40s  ->  %s", $s, $q ) );

    #diag( $q->dump );

}

