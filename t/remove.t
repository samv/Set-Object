use Set::Object;

require 't/Person.pm';
package Person;

populate();

$patty = $patty;
$selma = $selma;
$burns = $burns;

Set::Object->new->remove($patty);

$simpsons = Set::Object->new($homer, $marge, $bart, $lisa, $maggie);

print "1..3\n";

$removed = $simpsons->remove($homer);
print 'not ' unless $simpsons->size() == 4 && $removed == 1
   && $simpsons == Set::Object->new($marge, $bart, $lisa, $maggie);
print "ok 1\n";

$removed = $simpsons->remove($burns);
print 'not ' unless $simpsons->size() == 4 && $removed == 0;
print "ok 2\n";

$removed = $simpsons->remove($patty, $marge, $selma);
print 'not ' unless $simpsons->size() == 3 && $removed == 1;
print "ok 3\n";
