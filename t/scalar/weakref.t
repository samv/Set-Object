# -*- perl -*-

use Test::More tests => 7;
use Set::Object qw(set refaddr);
use Storable qw(dclone);

my $set = set();

{
    my $item = { };
    $set->insert($item);
    is($set->size, 1, "sanity check 1");
    $set->weaken;
    is($set->size, 1, "weaken not too eager");
}

is($set->size, 0, "weaken expires objects ");

$set->insert({});
is($set->size, 0, "weakened sets can't hold temporary objects");

my $structure = {
    bob => [ "Hi, I'm bob" ],
    who => set(),
};

$structure->{who}->insert($structure->{bob});
$structure->{who}->weaken;

my $clone = dclone $structure;

isnt(refaddr($structure->{bob}), refaddr($clone->{bob}), "sanity check 2");
isnt(${$structure->{who}}, ${$clone->{who}}, "sanity check 3");

delete $clone->{bob};

is($clone->{who}->members, 0, "weaken preserved over dclone()");
