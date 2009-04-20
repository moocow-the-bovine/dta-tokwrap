#!/usr/bin/perl -w

use lib qw(.);
use DTA::TokWrap;
use DTA::TokWrap::Document;
use DTA::TokWrap::mkindex;
use DTA::TokWrap::mkbx0;
use DTA::TokWrap::mkbx;

##----------------------------------------------------------------------
## Test: document
sub test_doc {
  our $test1 = DTA::TokWrap::Document->new('xmlfile'=>'test1.chr.xml');
  our $ex1   = DTA::TokWrap::Document->new('xmlfile'=>'ex1.chr.xml');
  our $testdoc = $test1;
  return $testdoc;
}
BEGIN { test_doc(); }

##----------------------------------------------------------------------
## Test: mkindex
sub test_mkindex {
  my $doc = shift;
  $doc = $testdoc if (!$doc);
  my $mi = DTA::TokWrap::mkindex->new();
  $mi->mkindex($doc)
    || die("$0: mkindex() failed for doc '$doc->{xmlfile}': $!");

  print STDERR "test_mkindex(): done\n";
}
#test_mkindex;

##----------------------------------------------------------------------
## Test: mkbx0
sub test_mkbx0 {
  my $doc = shift;
  $doc = $testdoc if (!$doc);

  ##-- test mkbx0 (object)
  my $mbx0 = DTA::TokWrap::mkbx0->new();
  $mbx0->dump_hint_stylesheet('hint.xsl');
  $mbx0->dump_sort_stylesheet('sort.xsl');
  $mbx0->ensure_stylesheets();
  ##
  $mbx0->mkbx0($doc) or die("$0: mkbx0() failed for '$doc->{xmlfile}': $!");
  $doc->{bx0doc}->toFile($doc->{bx0file},1);

  ##-- test mkbx0 (doc method)
  unlink($doc->{sxfile}) if (-e $doc->{sxfile}); ##-- test implicit mkindex()
  $doc->mkbx0();
  $doc->{bx0doc}->toFile($doc->{bx0file},1);

  print STDERR "$0: test_mkbx0() done\n";
}
#test_mkbx0();

##----------------------------------------------------------------------
## Test: mkbx
sub test_mkbx {
  my $doc = shift;
  $doc = $testdoc if (!$doc);

  ##-- test mkbx (object)
  my $mbx = DTA::TokWrap::mkbx->new();
  $mbx->mkbx($doc) or die("$0: mkbx() failed for '$doc->{xmlfile}': $!");
  $doc->saveTxtFile() or die("$0: saveTxtFile() failed for '$doc->{xmlfile}': $!");
  $doc->saveBxFile() or die("$0: saveBxFile() failed for '$doc->{xmlfile}': $!");


  ##-- test mkbx (doc method)
  delete($doc->{bx0doc}); ##-- test implicit mkbx0()
  $doc->mkbx();
  $doc->saveBxFile() or die("$0: saveBxFile() failed for '$doc->{xmlfile}': $!");
  $doc->saveTxtFile() or die("$0: saveTxtFile() failed for '$doc->{xmlfile}': $!");

  print STDERR "$0: test_mkbx() done\n";
}
#test_mkbx();
test_mkbx($ex1);


##----------------------------------------------------------------------
## MAIN
foreach $i (1..3) {
  print STDERR "dummy($i)\n";
}
