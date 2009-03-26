#!/usr/bin/perl -w

use lib qw(.);
use DTA::TokWrap;

##----------------------------------------------------------------------
sub test1 {
  my $file = ($_[0] || 'test1.xml');
  our $dp = DTA::TokWrap::DocParser->new();
  our $doc = $dp->parsefile($file);

  print STDERR "test1: done\n";
}
#test1();
test1('examples/kraepelin_arzneimittel_1892.char.txt.xml');

##----------------------------------------------------------------------
## MAIN
foreach $i (1..3) {
  print STDERR "dummy($i)\n";
}
