use Set::Object;

print "1..2\n";

my $s = Set::Object->new("a");
my $t = Set::Object->new("b");

$s->insert($t);

print "not " unless $s eq "Set::Object(Set::Object(b) a)";
print "ok 1\n";

$t->insert($s);

# sure, this can be infinite with Set::Object.  I don't care.
#print "not " unless $s eq "(a (b (a ...)))";
#print "ok 2\n";
#
#print "not " unless $t eq "(b (a (b ...)))";
#print "ok 3\n";
#
#my $u = Set::Object->new("c");
#
#$u->insert($u);
#
#print "u is $u\n";
#print "not " unless $u == "(c (c ...))";
#print "ok 4\n";
#
#$s->insert($u);
#
## There is some nondeterminism that needs to be resolved.
#print "not " unless $s == "(a (b (a ...)) (c ...))" or
                    #$s == "(a (b (a (c ...) ...)) (c ...))";
#print "ok 5\n";
#
#print "not " unless $t == "(b (a (b ...) (c ...)))" or
                    #$t == "(b (a (b (c ...) ...) (c ...)))";
#print "ok 6\n";
#
$t->delete($s);
#
#print "not " unless $s == "(a (b) (c ...))";
#print "ok 7\n";
#
print "not " unless $t eq "Set::Object(b)";
print "ok 2\n";

