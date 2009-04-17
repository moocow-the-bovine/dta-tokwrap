#!/usr/bin/perl -w

use lib qw(.);
use DTA::TokWrap;
use DTA::TokWrap::mkindex;

##----------------------------------------------------------------------
## Test: document
sub test_doc {
  our $doc = DTA::TokWrap::Document->new('xmlfile'=>'test1.chr.xml');
  return $doc;
}

##----------------------------------------------------------------------
## Test: mkindex
sub test_mkindex {
  my $doc = shift;
  $doc = test_doc() if (!$doc);
  my $mi = DTA::TokWrap::mkindex->new();
  $mi->mkindex($doc)
    || die("$0: mkindex() failed for doc '$doc->{xmlfile}': $!");

  print STDERR "test_mkindex(): done\n";
}
#test_mkindex;

##----------------------------------------------------------------------
## Test: mkbx0
use DTA::TokWrap::mkbx0;
sub test_mkbx0 {
  my $mb = DTA::TokWrap::mkbx0->new();

  $mb->dump_hint_stylesheet('hint.xsl');
  $mb->dump_sort_stylesheet('sort.xsl');
  $mb->ensure_stylesheets();

  print STDERR "$0: test_mkbx0() done\n";
}
test_mkbx0();


##----------------------------------------------------------------------
## MAIN
foreach $i (1..3) {
  print STDERR "dummy($i)\n";
}
