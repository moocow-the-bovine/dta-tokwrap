use Config;
use ExtUtils::MakeMaker;
use 5.010; ##-- in case old EU::MM doesn't grok MIN_PERL_VERSION
use strict;

##----------------------------------------------------------------------
## dummy MakeMaker
WriteMakefile
  (
   NAME		=> 'DTA::TokWrap',
   DISTNAME     => 'dta-tokwrap',
   AUTHOR       => 'Bryan Jurish <moocow@cpan.org>',
   ABSTRACT	=> 'Utility suite for DTA-style XML corpus tokenization',
   VERSION_FROM	=> 'DTA-TokWrap/TokWrap/Version.pm',
   LICENSE      => 'perl_5',
   MIN_PERL_VERSION => 5.010, ##-- v5.10.0

   PREREQ_PM    => {
		    'XML::Parser' => 0,
		    'XML::LibXML' => 0,
		    'XML::LibXSLT' => 0,
		    'Encode'=>0,
		    'Time::HiRes'=>1.9711,
		    'Getopt::Long'=>0,
		    'Pod::Usage'=>0,
		    'Env::Path' =>0.18,
		    'File::Basename'=>0,
		    'Cwd'=>0,
		    'Log::Log4perl'=>1.20,
		    'Algorithm::BinarySearch::Vec'=>0.05, ##-- only really required for for dtatw-get-ddc-attrs.perl
		    ##
		    'Test::More'=>0,
		    ##--
		    #'Tie::Cache'=>0,
		    #'File::Basename'=>0,
		    #'Getopt::Long'=>0,
		    #'Pod::Usage'=>0,
		    #'Storable'=>0,
		    ##--
		    #'Log::Log4perl' => 1.07,
		    #'Text::Unidecode' => 0.04,
		    #'RPC::XML' => 0.59,
		   },

   ##-- don't let EU::MM recurse -- let automake handle the actual build
   DIR => [],
  );
rename("Makefile","Makefile_mm");


##----------------------------------------------------------------------
## autoconf-style configure (also creates DTA-TokWrap/Version.pm)
$ENV{CPPFLAGS} .= " ".$Config{cppflags};
$ENV{LDFLAGS}  .= " ".$Config{ldflags};

-e "./configure"
  or system(qw(autoreconf --install --verbose --force .))==0
  or die("$0: ERROR: ./autoreconf.sh failed: $!");
system(qw(sh ./configure --disable-doc),@ARGV)==0
  or die("$0: ERROR: autotools ./configure failed: $!");



