use Set::Object;

require 't/object/Person.pm';
package Person;

populate();

$simpsons = Set::Object->new($homer, $marge);
$bouviers = Set::Object->new($marge, $patty, $selma);
$both = Set::Object->new($homer, $marge, $patty, $selma);
$empty = Set::Object->new;

print "1..5\n";

print 'not ' unless $simpsons->union($bouviers) == $both;
print "ok 1\n";

print 'not ' unless $simpsons + $bouviers == $both;
print "ok 2\n";

print 'not ' unless $bouviers + $simpsons == $both;
print "ok 3\n";

print 'not ' unless $simpsons + $simpsons == $simpsons;
print "ok 4\n";

print 'not ' unless $simpsons + $empty == $simpsons;
print "ok 5\n";
