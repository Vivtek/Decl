#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Decl' ) || print "Bail out!\n";
}

diag( "Testing Decl $Decl::VERSION, Perl $], $^X" );
