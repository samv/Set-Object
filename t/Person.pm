
package Person;

sub new
{
   ++$n;
   my $type = shift;
   my $self = bless { @_ }, $type;
   return $self;
}

sub DESTROY
{
   --$n;
}

sub populate
{
   no strict 'vars';
   
   $homer = new Person( firstname => 'Homer', name => 'Simpson' );
   $marge = new Person( firstname => 'Marge', name => 'Simpson' );
   $bart = new Person( firstname => 'Bart', name => 'Simpson' );
   $lisa = new Person( firstname => 'Lisa', name => 'Simpson' );
   $maggie = new Person( firstname => 'Maggie', name => 'Simpson' );

   @simpsons = ($homer, $marge, $bart, $lisa, $maggie);

   $burns = new Person( firstname => 'Montgomery', name => 'Burns' );
   $skinner = new Person( firstname => 'Seymour', name => 'Skinner' );

   $patty = new Person( firstname => 'Patty', name => 'Bouvier' );
   $selma = new Person( firstname => 'Selma', name => 'Bouvier' );

   $n;
}

sub exterminate
{
   no strict 'vars';
   
   undef $homer;
   undef $marge;
   undef $bart;
   undef $lisa;
   undef $maggie;

   undef @simpsons;

   undef $burns;
   undef $skinner;

   undef $patty;
   undef $selma;

   $n;
}

sub same
{
   my ($l1, $l2) = @_;
   my @l1 = sort { $a->{firstname} cmp $b->{firstname} } @$l1;
   my @l2 = sort { $a->{firstname} cmp $b->{firstname} } @$l2;
   foreach (@l1) { return 'not ' unless $_ eq shift @l2 }
   '';
}

1;
