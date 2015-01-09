#!perl -T

use Test::More tests => 2;

BEGIN {
    use_ok( 'Decl' ) || print "Bail out!\n";
}

diag( "Testing Decl $Decl::VERSION, Perl $], $^X" );

use_ok ('Decl::Syntax');
