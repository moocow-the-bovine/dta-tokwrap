#use ExtUtils::MakeMaker;
use strict;

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------

##----------------------------------------------------------------------
## autoconf-style (also creates DTA-TokWrap/Version.pm)
-e "./configure"
  or system(qw(autoreconf --install --verbose --force .))==0
  or die("$0: ERROR: ./autoreconf.sh failed: $!");
system(qw(sh ./configure --disable-doc),@ARGV)==0
  or die("$0: ERROR: autotools ./configure failed: $!");



