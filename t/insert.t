use Set::Object;

require 't/Person.pm';
package Person;

populate();

$simpsons = Set::Object->new;

print "1..5\n";

print 'not' unless $simpsons->size() == 0;
print "ok 1\n";

$added = $simpsons->insert($homer);
print 'not' unless $simpsons->size() == 1 && $added == 1;
print "ok 2\n";

$added = $simpsons->insert($homer);
print 'not' unless $simpsons->size() == 1 && $added == 0;
print "ok 3\n";

$added = $simpsons->insert($marge);
print 'not' unless $simpsons->size() == 2 && $added == 1;
print "ok 4\n";

$simpsons->insert($maggie, $homer, $bart, $marge, $bart, $lisa, $lisa, $maggie);
print 'not' unless $simpsons->size() == 5;
print "ok 5\n";

