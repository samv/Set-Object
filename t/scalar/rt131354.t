# RT 131354, perl5.28 regression
use Set::Object qw/ set /;
use Test::More tests => 2;

my $a = set("a", "b", "c");
my $b = set();
$added = $b->insert(@$a);
is($added, 3, "Set::Object->insert() [ returned # added ]");
is($b->size(), 3, "Set::Object->size() [ three members ]");
