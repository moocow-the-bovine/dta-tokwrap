use ExtUtils::MakeMaker;

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
WriteMakefile
  (
   NAME		=> 'DTA::TokWrap',
   AUTHOR       => 'Bryan Jurish <moocow@bbaw.de>',
   ABSTRACT	=> 'Wrapper modules & scripts for DTA XML corpus tokenization',
   VERSION_FROM	=> 'TokWrap/Version.pm',

   PREREQ_PM    => {
		    'XML::Parser' => undef,
		    'XML::LibXML' => undef,
		    'XML::LibXSLT' => undef,
		    'Encode'=>undef,
		    'Time::HiRes'=>1.9711,
		    'Getopt::Long'=>undef,
		    'Pod::Usage'=>undef,
		    'Env::Path' =>0.18,
		    'File::Basename'=>undef,
		    'Cwd'=>undef,
		    'Log::Log4perl'=>undef,
		    ##--
		    #'Tie::Cache'=>undef,
		    #'File::Basename'=>undef,
		    #'Getopt::Long'=>undef,
		    #'Pod::Usage'=>undef,
		    #'Storable'=>undef,
		    ##--
		    #'Log::Log4perl' => 1.07,
		    #'Text::Unidecode' => 0.04,
		    #'RPC::XML' => 0.59,
		   },

   EXE_FILES   => [
		   'dta-tokwrap.perl',
		  ],
  );


##-----------------------------------------------------------------------
## Extensions
##-----------------------------------------------------------------------

##---------------------------------------------------------------
sub MY::depend {
  package MY;
  my $inherited = shift->SUPER::depend(@_);
  $inherited .= (
		 ###-- depends -> README.txt
		 "\n\n"
		 ."dist: README.txt\n"
		 ."\n"
		 ."create_distdir: README.txt\n"
		 #."distdir_am: README.txt\n"
		 ."\n"
		 ."distcheck: README.txt\n"
		 ."\n"
		 ."manicheck: README.txt\n"
		 ."\n"
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
\tpod2html --outfile \$@ \$<

.pm.txt:
\tpod2text \$< \$@

.pod.html:
\tpod2html --outfile \$@ \$<

.pod.txt:
\tpod2text \$< \$@

.rpod.html:
\tpod2html --outfile \$@ \$<

.rpod.txt:
\tpod2text \$< \$@

";
  return $inherited;
}


##---------------------------------------------------------------
sub MY::distdir {
  package MY;
  my $inherited = shift->SUPER::distdir(@_);
  my $local =
'
##-- distdir_am: hacked create_distdir for superordinate automake
DISTDIR_AM ?= $(DISTNAME).am
distdir_am: distdir
	$(RM_RF) $(DISTDIR_AM)
	$(MV) $(DISTVNAME) $(DISTDIR_AM)
';
#	$(PERLRUN) "-MExtUtils::Manifest=manicopy,maniread" \\
#	           -e "manicopy(maniread(),\'$(DISTDIR_AM)\', \'$(DIST_CP)\');"

  return $inherited.$local;
}

##---------------------------------------------------------------
sub MY::postamble {
  package MY;
  my $inherited = shift->SUPER::postamble(@_);
  return $inherited;
}
