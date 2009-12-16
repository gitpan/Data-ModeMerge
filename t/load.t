#!perl -T

use Test::More tests => 8;

BEGIN {
	use_ok( 'Data::ModeMerge' );
	use_ok( 'Data::ModeMerge::Config' );
	#use_ok( 'Data::ModeMerge::Mode::Base' );
	use_ok( 'Data::ModeMerge::Mode::ADD' );
	use_ok( 'Data::ModeMerge::Mode::CONCAT' );
	use_ok( 'Data::ModeMerge::Mode::DELETE' );
	use_ok( 'Data::ModeMerge::Mode::KEEP' );
	use_ok( 'Data::ModeMerge::Mode::NORMAL' );
	use_ok( 'Data::ModeMerge::Mode::SUBTRACT' );
}

diag( "Testing Data::ModeMerge $Data::ModeMerge::VERSION, Perl $], $^X" );
