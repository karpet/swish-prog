use strict;
use warnings;
use Test::More tests => 5;
use Data::Dump qw( dump );
use File::Temp;
use XML::Simple;

sub make_pretty_xml {
    my $xml = shift;
    my $file = File::Temp->new( UNLINK => 1 );
    print $file $xml;
    my @pretty = `xmllint --format $file`;
    return join '', @pretty;
}

my $utils = 'SWISH::Prog::Utils';
use_ok($utils);

my $data1 = {
    foo   => 'bar',
    array => [
        'one' => 1,
        'two' => 2,
    ],
    hash => {
        three => 3,
        four  => 4,
    },
};

my $expect_data1_xml
    = "<data1><hash><three>3</three><four>4</four></hash><array><array>one</array><array>1</array><array>two</array><array>2</array></array><foo>bar</foo></data1>";

ok( my $data1_xml = $utils->perl_to_xml( $data1, 'data1' ), "data1 to xml" );
is( $data1_xml, $expect_data1_xml, "data1 xml" );

#warn( make_pretty_xml($data1_xml) );
#warn( XMLout($data1) );

my $data2 = {
    arrays => [
        {   two   => 2,
            three => 3,
        },
        {   four => 4,
            five => 5,
        },
    ],
};

my $expected_data2_xml
    = "<data2><arrays><array><three>3</three><two>2</two></array><array><five>5</five><four>4</four></array></arrays></data2>";

# exercise $strip_plural
ok( my $data2_xml = $utils->perl_to_xml( $data2, 'data2', 1 ),
    "data2 to xml" );

is( $data2_xml, $expected_data2_xml, "data2 xml" );

#warn $data2_xml;

#warn( make_pretty_xml($data2_xml) );
#warn( XMLout( $data2, NoAttr => 1 ) );
