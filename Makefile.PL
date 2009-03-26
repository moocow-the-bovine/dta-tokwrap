use ExtUtils::MakeMaker;

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
WriteMakefile
  (
   NAME		=> 'DTA::TokWrap',
   AUTHOR       => 'Bryan Jurish <moocow@bbaw.de>',
   ABSTRACT	=> 'Wrapper modules & scripts for DTA corpus tokenization',
   VERSION_FROM	=> 'TokWrap.pm',

   PREREQ_PM    => {
		    XML::Parser => undef,
		    ##--
		    #'Encode'=>undef,
		    #'Tie::Cache'=>undef,
		    #'File::Basename'=>undef,
		    #'Getopt::Long'=>undef,
		    #'Pod::Usage'=>undef,
		    #'Storable'=>undef,
		    #'Time::HiRes'=>undef,
		    ##--
		    #'Log::Log4perl' => 1.07,
		    #'Text::Unidecode' => 0.04,
		    #'RPC::XML' => 0.59,
		   },

   EXE_FILES   => [
		   #'dta-tokwrap.perl',
		  ],
  );


##-----------------------------------------------------------------------
## Extensions
##-----------------------------------------------------------------------

sub MY::postamble {
  # how to format the README file
  "README.txt : README.rpod\n"
  ."\tpod2text README.rpod README.txt\n\n";
}

sub MY::dist_core {
  package MY;
  my $inherited = shift->SUPER::dist_core(@_);
  $inherited =~
    # ... distribution requires current README file
    s/^dist\s*:/dist\ : README.txt/m;
  $inherited;
}
