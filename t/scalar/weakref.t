# -*- perl -*-

use Test::More tests => 4;
use Set::Object qw(set);

my $set = set();

{
    my $item = { };
    $set->insert($item);
    is($set->size, 1, "sanity check");
    $set->weaken;
    is($set->size, 1, "weaken not too eager");
}

is($set->size, 0, "weaken expires objects ");

$set->insert({});
is($set->size, 0, "weakened sets can't hold temporary objects");
