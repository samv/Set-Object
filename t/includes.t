use Set::Object;

require 't/Person.pm';
package Person;

populate();

$simpsons = Set::Object->new( $homer, $marge, $bart, $lisa, $maggie );

print "1..5\n";

print 'not' unless $simpsons->includes();
print "ok 1\n";

print 'not' unless $simpsons->includes($bart);
print "ok 2\n";

print 'not' unless $simpsons->includes($homer, $marge, $bart, $lisa, $maggie);
print "ok 3\n";

print 'not' if $simpsons->includes($burns);
print "ok 4\n";

print 'not' if $simpsons->includes($homer, $burns, $marge);
print "ok 5\n";
