use aliased 'Set::Object' => 'Set::Scalar';

print "1..2\n";

my @a = qw(One Two Three);     
my @b = qw(Four Five Six);
 
my $ssa = Set::Scalar->new(@a);
my $ssb = Set::Scalar->new(@b);
 
print "not " unless $ssa;
print "ok 1\n";

my $is = $ssa->intersection($ssb);
print "not " if $is->size;
print "ok 2 - $is\n";

