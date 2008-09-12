use Set::Object;

use Test::More tests => 5;

require 't/object/Person.pm';
package Person;

populate();

$simpsons = Set::Object->new($homer, $marge);
$bouviers = Set::Object->new($marge, $patty, $selma);
$both = Set::Object->new($homer, $marge, $patty, $selma);
$empty = Set::Object->new;

::ok( $simpsons->union($bouviers) == $both, "union method" );

::ok( $simpsons + $bouviers == $both, "op_union" );

::ok( $bouviers + $simpsons == $both, "op union with ops reversed" );

::ok( $simpsons + $simpsons == $simpsons, "union with self" );

::ok( $simpsons + $empty == $simpsons, "union with empty set" );
