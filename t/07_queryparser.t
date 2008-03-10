use Test::More tests => 2;


use_ok('SWISH::Prog::QueryParser');

my %str = (

    'foo AND bar'           => '',
    'bar OR foo'            => '',
    'foo NEAR10 bar'        => '',
    'foo NOT bar'           => '',
    'title:foo OR body:bar' => '',
    '(foo AND bar) or quz'  => '',

);

ok( my $parser = SWISH::Prog::QueryParser->new, "parser" );

for my $s ( sort keys %str ) {
    my $q = $parser->parse($s);
    #diag("$s  ->  $q");
    #diag( $q->dump );

}

