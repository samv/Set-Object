use ExtUtils::MakeMaker;

unless (eval { require Test::More; 1 }) {
	print STDERR "*** Test::More is not installed, you will not be able to run the tests\n";
}
unless ($] >= 5.006001) {
	print STDERR "*** This Perl version ($]) is not supported\n";
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
  'NAME'	=> 'Set::Object',
  'VERSION_FROM' => 'lib/Set/Object.pm', # finds $VERSION
  'AUTHOR'    => 'Jean-Louis Leroy and Sam Vilain',
  'LICENSE'   => 'Artistic',
  'ABSTRACT'  => "Unordered collections (sets) of Perl Objects",
  'PREREQ_PM' => {
    'Scalar::Util'    => 0,
    'Test::LeakTrace' => 0,
    'Test::More'      => 0
  },
  test => { TESTS => join(' ', glob('t/*/*.t')) },
);
