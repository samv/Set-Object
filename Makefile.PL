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
    'AUTHOR'    => 'Jean-Louis Leroy and Sam Vilain',
    'LICENSE'   => 'Artistic',
    'VERSION_FROM' => 'lib/Set/Object.pm', # finds $VERSION
    'ABSTRACT'  => "Unordered collections (sets) of Perl Objects",
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '',     # e.g., '-I/usr/include/other' 
    PM => {'lib/Set/Object.pm' => '$(INST_LIBDIR)/Object.pm',
	   'lib/Set/Object/Weak.pm' => '$(INST_LIBDIR)/Object/Weak.pm',
	  },
    PREREQ_PM => { 'Scalar::Util' => 0 },
    test => { TESTS => join(' ', glob('t/*/*.t')) },
);
