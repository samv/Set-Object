use Set::Object;

use Test::More tests => 10;

require 't/object/Person.pm';
package Person;

populate();

foreach my $class ( qw(Set::Object Set::Object::Weak) ) {
	$simpsons = $class->new($homer, $marge);
	$bouviers = $class->new($marge, $patty, $selma);
	$both = $class->new($homer, $marge, $patty, $selma);
	$empty = $class->new;

	::ok( $simpsons->union($bouviers) == $both, "union method" );

	::ok( $simpsons + $bouviers == $both, "op_union" );

	::ok( $bouviers + $simpsons == $both, "op union with ops reversed" );

	::ok( $simpsons + $simpsons == $simpsons, "union with self" );

	::ok( $simpsons + $empty == $simpsons, "union with empty set" );
}
