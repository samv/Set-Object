#  -*- perl -*-

use Set::Object;
use Test::More tests => 15;

my $bob = bless {}, "Bob";
my $bert = bless {}, "Bert";

my $set = set(0, 1, 2, 3, $bob);

isa_ok($set, "Set::Object", "set()");

is(@$set, 5, "scalar list context");
push @$set, 13;
ok($set->includes(13), "tied array PUSH");
unshift @$set, 17;
ok($set->includes(17), "tied array UNSHIFT");

print "not " unless @items == 5;
print "ok 6 # \@{} operator\n";

print "not " unless $set->{$bob};
print "ok 2 # %{} operator - object\n";
print "not " unless $set->{0};
print "ok 3 # %{} operator - scalar\n";

print "not " if $set->{4};
print "ok 4 # %{} operator - scalar (negative)\n";
print "not " if $set->{$bert};
print "ok 5 # %{} operator - object (negative)\n";

