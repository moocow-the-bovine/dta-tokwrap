use ExtUtils::MakeMaker;

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
WriteMakefile
  (
   NAME		=> 'Algorithm::BinarySearch::Vec::XS',
   AUTHOR       => 'Bryan Jurish <moocow@cpan.org>',
   ABSTRACT	=> 'fast binary search functions for vec() vectors',
   VERSION_FROM	=> 'XS.pm',

   ##-- user variables
   #CC           => 'c++',   ##-- your c++ compiler
   #LIBS         => "$MY_LDFLAGS $MY_LIBS",      ##-- additional libraries
   #DEFINE       => '-DHAVE_CONFIG_H',     ##-- additional defines
   #INC          => $MY_IFLAGS,      ##-- additional includes
   #CCFLAGS      => '',          ##-- additional flags
   OPTIMIZE    => '-O2 -pipe',  ##-- optimization flags
   #OBJECT      => 'foo.o',

   ##-- install these
   #EXE_FILES => [glob("*.perl")],

   ##-- DEBUG
   #MAKEAPERL=>1,
   ##LINKTYPE=>'static',
   #MAP_TARGET=>'ucperl',
   ##INCLUDE_EXT=>[qw(Encode DynaLoader Exporter)], ##-- ??? doesn't work ???
   #CCFLAGS=>'-g',
   ##-- /DEBUG

   ##-- stuff that probably doesn't need to be changed
   #XSOPT        => '-C++',
   #TYPEMAPS     => ['perlobject.map', 'typemap'],

   ##-- prerequisites
   PREREQ_PM    => {
		    #'Module' => $version,
		   },
  );


#-----------------------------------------------------------------------
# Extensions
#-----------------------------------------------------------------------

##---------------------------------------------------------------
sub MY::constants {
  package MY;
  my $inherited = shift->SUPER::constants(@_);
  return $inherited;
}

##---------------------------------------------------------------
sub MY::depend {
  package MY;
  my $inherited = shift->SUPER::depend(@_);
  $inherited .= (
		 ###-- depends -> README.txt
		 "\n\n"
		 .join('',
		      map {
			"$_: README.txt\n\n"
		      } qw(dist create_distdir distdir_am distcheck manicheck))
		);
  return $inherited;
}

##---------------------------------------------------------------
sub MY::special_targets {
  package MY;
  my $inherited = shift->SUPER::special_targets(@_);
  $inherited .=
"
.SUFFIXES: .pm .pod .rpod .man .txt .html

.pm.html:
\tpod2html --css=\$(CSS) --infile=\$< --outfile=\$@

.pm.txt:
\tpod2text \$< \$@

.pod.html:
\tpod2html --css=\$(CSS) --infile=\$< --outfile=\$@

.pod.txt:
\tpod2text \$< \$@

.rpod.html:
\tpod2html --css=\$(CSS) --infile=\$< --outfile=\$@

.rpod.txt:
\tpod2text \$< \$@

";
  return $inherited;
}

##---------------------------------------------------------------
sub MY::postamble {
  package MY;
  my $inherited = shift->SUPER::postamble(@_);
  return $inherited;
}
