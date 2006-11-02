use strict;
use threads;
use threads::shared;
use Set::Object;

my $sh = new Set::Object();
share($sh);

my $t1 = threads->new(\&f1);
my $t2 = threads->new(\&f2);

main();

$t1->join;
$t2->join;

sub f1{
  foreach my $i (1..10000000){
    my $d = $i % 10;
    $sh->remove($d) if $sh->element($d);
  }
}

sub f2{
  foreach my $i (1..10000000){
    my $d = $i % 10;
    $sh->remove($d);
  }
}

sub main{
  my $d;
  foreach my $i (1..10000000){
   my $d = $i % 10;
   $sh->insert($d);
  }
}


