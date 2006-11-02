use strict;
require Test::More;
BEGIN {
    eval 'use threads';
    if ($@) {
	Test::More->import( 'skip_all' => 'threads.pm failed to load' );
	exit(0);
    }
}
use threads::shared;
use Set::Object;

my $sh = new Set::Object();
my $failed;
share($sh);
share($failed);

$SIG{__WARN__} = sub { $failed = 1; warn @_ };
print "1..1\n";

my $t1 = threads->new(\&f1);
my $t2 = threads->new(\&f2);

main();

$t1->join;
$t2->join;

print "not " if $failed;
print "ok 1\n";

sub f1{
  foreach my $i (1..10000){
    my $d = $i % 10;
    $sh->remove($d) if $sh->element($d);
  }
}

sub f2{
  foreach my $i (1..10000){
    my $d = $i % 10;
    $sh->remove($d);
  }
}

sub main{
  my $d;
  foreach my $i (1..10000){
   my $d = $i % 10;
   $sh->insert($d);
  }
}


