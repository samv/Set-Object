use Set::Object;

require 't/Person.pm';
package Person;

populate();

$simpsons = Set::Object->new();

print "1..3\n";

print 'not ' if $simpsons->members();
print "ok 1\n";

@members1 = @simpsons;
@members1 = sort { $a->{firstname} cmp $b->{firstname} } @members1;

$simpsons->insert(@members1);
print 'not ' unless $simpsons->members() != 5;
print "ok 2\n";

@members2 = sort { $a->{firstname} cmp $b->{firstname} } $simpsons->members();

foreach $member1 (@members1)
{
   if ($member1 != shift(@members2)) { print 'not '; last }
}

print "ok 3\n";
