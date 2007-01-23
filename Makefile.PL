use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Set::Object',
    'VERSION_FROM' => 'lib/Set/Object.pm', # finds $VERSION
    'ABSTRACT'  => "Unordered collections (sets) of Perl Objects",
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '',     # e.g., '-I/usr/include/other' 
    PM => {'lib/Set/Object.pm' => '$(INST_LIBDIR)/Object.pm',
	   'lib/Set/Object/Weak.pm' => '$(INST_LIBDIR)/Object/Weak.pm',
	  },
    test => { TESTS => join(' ', glob('t/*/*.t')) },
);
