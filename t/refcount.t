use Set::Object;

require 't/Person.pm';
package Person;

print "1..6\n";

$simpsons = Set::Object->new(
   new Person( firstname => 'Bart', name => 'Simpson' ),
   new Person( firstname => 'Lisa', name => 'Simpson' ),
   new Person( firstname => 'Maggie', name => 'Simpson' ) );

print 'not' unless $Person::n == 3;
print "ok 1\n";

$simpsons->insert();
print 'not' unless $Person::n == 3;
print "ok 2\n";

$simpsons->insert($homer = new Person( firstname => 'Homer', name => 'Simpson' ));
print 'not' unless $Person::n == 4;
print "ok 3\n";

$simpsons->remove($homer);
print 'not' unless $Person::n == 4;
print "ok 4\n";

undef $homer;
print 'not' unless $Person::n == 3;
print "ok 5\n";

undef $simpsons;
print 'not' if $Person::n;
print "ok 6\n";
