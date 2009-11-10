use strict;
use warnings;
use Test::More tests => 10;
use File::Slurp;
use Path::Class::Dir;

TODO: {
    local $TODO = "ver2_to_ver3 not yet implemented";

    # test ver2 to ver3 conversion
    use_ok('SWISH::Prog::Config');

    my $ver2_dir = Path::Class::Dir->new('t/config2');
    my $ver3_dir = Path::Class::Dir->new('t/config3');

SKIP: {
        skip "ver2_to_ver3 not implemented", 9;

        while ( my $file = $ver2_dir->next ) {
            next if -d $file;
            diag("converting $file");
            my $xml = SWISH::Prog::Config->ver2_to_ver3("$file");

            #diag($xml);
            my $filename  = $file->basename;
            my $ver3_file = $ver3_dir->file( $filename . ".xml" );
            my $ver3      = read_file("$ver3_file");
            is( $xml, $ver3, "$file to xml" );

        }

    }

}
