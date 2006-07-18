# -*- perl -*-

use Test::More tests => 10;
use Set::Object qw(set refaddr);
use Storable qw(dclone);

my $set = set();

{ package MyClass;
  our $c;
  sub new { $c++; my $pkg = shift;
	    my $self = bless {@_}, $pkg;
	    #print STDERR "# NEW - $self\n";
	    $self;
	}
  sub DESTROY {
      my $self = shift;
      #print STDERR "# FREE - $self\n";
      $c-- }
}

#use Devel::Peek;

{
    my $item = MyClass->new;
    $set->insert($item);
    is($set->size, 1, "sanity check 1");
    #diag(Dump($item));
    $set->weaken;
    #diag(Dump($item));
    is($set->size, 1, "weaken not too eager");
}

is($MyClass::c, 0, "weaken makes refcnt lower");
is($set->size, 0, "Set knows that the object expired");
diag($_) for $set->members;

$set->insert(MyClass->new);
is($set->size, 0, "weakened sets can't hold temporary objects");

my $structure = MyClass->new
    (
     bob => [ "Hi, I'm bob" ],
     who => set(),
    );

$structure->{who}->insert($structure->{bob});
$structure->{who}->weaken;

#diag("now cloning");

my $clone = dclone $structure;

isnt(refaddr($structure->{bob}), refaddr($clone->{bob}), "sanity check 2");
isnt(${$structure->{who}}, ${$clone->{who}}, "sanity check 3");

is($clone->{who}->size, 1, "Set has size");
is(($clone->{who}->members)[0], $clone->{bob}, "Set contents preserved");

delete $clone->{bob};

is($clone->{who}->size, 0, "weaken preserved over dclone()");
