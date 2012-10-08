use ExtUtils::MakeMaker;

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
WriteMakefile
  (
   NAME		=> 'Algorithm::BinarySearch::Vec',
   AUTHOR       => 'Bryan Jurish <moocow@cpan.org>',
   ABSTRACT	=> 'binary search on vec() vectors',
   VERSION_FROM	=> 'Vec.pm',

   ##-- user variables
   #CC           => 'c++',   ##-- your c++ compiler
   #LIBS         => "$UX_LDFLAGS $UX_LIBS",      ##-- additional libraries
   #DEFINE       => '-DHAVE_CONFIG_H',     ##-- additional defines
   #INC          => $UX_IFLAGS,      ##-- additional includes
   #CCFLAGS      => '',          ##-- additional flags
   OPTIMIZE    => '-O2 -pipe', ##-- optimization flags
   #OBJECT      => 'Gfsm.o GfsmPerl.o',

   ##-- install these
   EXE_FILES => [glob("*.perl")],

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
		    #'Encode' => undef,
		   },
  );


#-----------------------------------------------------------------------
# Extensions
#-----------------------------------------------------------------------

##---------------------------------------------------------------
sub MY::constants {
  package MY;
  my $css = 'moopod.css';
  my $inherited = shift->SUPER::constants(@_);
  $inherited .= (
		 ###-- constants: html css
		 "\n"
		 ."CSS ?= $css\n"
		);
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
			#"$_: README.txt\n\n",
			''
		      }
		      qw(dist create_distdir distdir_am distcheck manicheck)
		     )
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
