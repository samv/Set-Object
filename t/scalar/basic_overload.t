use aliased "Set::Object" => "Set::Scalar";

use strict;

print "1..30\n";

my $s = Set::Scalar->new;

print "not " unless $s->size == 0;
print "ok 1\n";

print "not " unless $s->is_null;
print "ok 2\n";

print "not " unless $s->is_universal;
print "ok 3\n";

print "not " unless $s eq "Set::Object()";
print "ok 4\n";

print "not " unless $s->universe eq "Set::Object()";
print "ok 5\n";

$s += "a";

print "not " unless $s->size == 1;
print "ok 6\n";

print "not " if $s->is_null;
print "ok 7\n";

print "not " unless $s->is_universal;
print "ok 8\n";

print "not " unless $s eq "Set::Object(a)";
print "ok 9\n";

print "not " unless $s->universe eq "Set::Object(a)";
print "ok 10\n";

$s += "a";

print "not " unless $s->size == 1;
print "ok 11\n";

print "not " if $s->is_null;
print "ok 12\n";

print "not " unless $s->is_universal;
print "ok 13\n";

print "not " unless $s eq "Set::Object(a)";
print "ok 14\n";

print "not " unless $s->universe eq "Set::Object(a)";
print "ok 15\n";

$s += "b";
$s += "c";
$s += "d";
$s += "e";

print "not " unless $s->size == 5;
print "ok 16\n";

print "not " if $s->is_null;
print "ok 17\n";

print "not " unless $s->is_universal;
print "ok 18\n";

print "not " unless $s eq "Set::Object(a b c d e)";
print "ok 19\n";

print "not " unless $s->universe eq "Set::Object(a b c d e)";

print "ok 20\n";

$s -= "b";
$s -= "d";

print "not " unless $s->size == 3;
print "ok 21\n";

print "not " if $s->is_null;
print "ok 22\n";

print "not " if $s->is_universal;
print "ok 23\n";

print "not " unless $s eq "Set::Object(a c e)";
print "ok 24\n";

print "not " unless $s->universe eq "Set::Object(a b c d e)";

print "ok 25\n";

$s /= "b";
$s /= "c";
$s /= "d";

print "not " unless $s->size == 4;
print "ok 26\n";

print "not " if $s->is_null;
print "ok 27\n";

print "not " if $s->is_universal;
print "ok 28\n";

print "not " unless $s eq "Set::Object(a b d e)";
print "ok 29\n";

print "not " unless $s->universe eq "Set::Object(a b c d e)";

print "ok 30\n";

# End Of File.

sub show {
    my $z = shift;

    print "# set: ".sprintf("SV = %x, addr = %x", Set::Object::refaddr($z), $$z)."\b";
    print "# size is: ",($z->size),"\n";
    print "# stringified: $z\n";
    print "# universe is: ",($z->universe),"\n";
}

