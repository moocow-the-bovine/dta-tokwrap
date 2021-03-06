#!/usr/bin/perl -w

use lib qw(.);
use DTA::TokWrap;
use DTA::TokWrap::Utils qw(:all);

##----------------------------------------------------------------------
## Test: logger
BEGIN {
  DTA::TokWrap::Logger->logInit();
}

##----------------------------------------------------------------------
## Test: document
sub test_doc {
  our $test1 = DTA::TokWrap::Document->open('test1.chr.xml');
  our $ex1   = DTA::TokWrap::Document->open('ex1.chr.xml');
  our $ex2   = DTA::TokWrap::Document->open('../test/ex2.chr.xml');
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
#test_mkbx($ex1);

##----------------------------------------------------------------------
## Test: tokenize: dummy
sub test_tokenize_dummy {
  my $doc = shift;
  $doc = $testdoc if (!$doc);

  ##-- test tokenize::dummy (object)
  my $td = DTA::TokWrap::tokenize::dummy->new();
  $td->tokenize($doc) or die("$0: tokenize() failed for '$doc->{xmlfile}': $!");
  $doc->saveTokFile() or die("$0: saveTokFile() failed for '$doc->{xmlfile}': $!");

  ##-- test tokenize (doc method)
  delete($doc->{txtfile}); ##-- test implicit saveTxtFile()
  $doc->tokenize();
  $doc->saveTokFile() or die("$0: saveTokFile() failed for '$doc->{xmlfile}': $!");

  print STDERR "$0: test_tokenize_dummy() done\n";
}
#test_tokenize_dummy();
#test_tokenize_dummy($ex1);


##----------------------------------------------------------------------
## Test: tok2xml
sub test_tok2xml {
  my $doc = shift;
  $doc = $testdoc if (!$doc);

  ##-- test tok2xml (object)
  my $t2x = DTA::TokWrap::tok2xml->new();
  $t2x->tok2xml($doc) or die("$0: tok2xml() failed for '$doc->{xmlfile}': $!");
  $doc->saveXtokFile() or die("$0: saveXtokFile() failed for '$doc->{xmlfile}': $!");

  ##-- test tok2xml (doc method)
  delete($doc->{bxdata});  ##-- test implicit mkbx()
  unlink($doc->{cxfile});  ##-- test implicit mkindex()
  delete($doc->{tokdata}); ##-- test implicit tokenize()
  $doc->tok2xml();
  $doc->saveXtokFile() or die("$0: saveXtokFile() failed for '$doc->{xmlfile}': $!");

  print STDERR "$0: test_tok2xml() done\n";
}
#test_tok2xml();
#test_tok2xml($ex1);

##----------------------------------------------------------------------
## Test: standoff
sub test_standoff {
  my $doc = shift;
  $doc = $testdoc if (!$doc);

  ##-- test standoff (object)
  if (0) {
    my $so = DTA::TokWrap::standoff->new();
    $so->standoff($doc) or die("$0: standoff() failed for '$doc->{xmlfile}': $!");
    $doc->saveStandoffFiles(format=>1) or die("$0: saveStandoffFiles() failed for '$doc->{xmlfile}': $!");
  }

  ##-- test tok2xml (doc method)
  delete(@$doc{qw(sosdoc sowdoc soadoc)});
  #$doc->standoff();
  $doc->saveStandoffFiles(format=>1);

  print STDERR "$0: test_standoff() done\n";
}
#test_standoff();
#test_standoff($ex1);
#test_standoff($ex2);

##----------------------------------------------------------------------
## Test: dependency tracking

sub test_deps {
  my $doc = shift;
  $doc = $testdoc if (!$doc);

  ##-- mark all data as stale
  system('touch', abs_path($doc->{xmlfile}));

  ##-- test trace
  #@$doc{qw(traceMake traceGen)} = (1,1);

  ##-- re-generate index
  #$doc->makeKey('cxfile');
  #$doc->makeKey('bxdata');
  ##--
  #$doc->makeKey('bxfile');
  #$doc->remakeKey('bxfile');
  ##--
  $doc->makeKey('all');

  print STDERR "$0: test_deps(): done\n";
}
#test_deps();
#test_deps($ex1);

##----------------------------------------------------------------------
## Test: open/close

sub test_openclose {
  my $xmlfile = shift || $testdoc->{xmlfile};
  my $tw = DTA::TokWrap->new();
  my ($doc);
  my %opts = (traceMake=>1);

  ##-- mark source file as newest & make (should re-make all)
  #system('touch', abs_path($xmlfile);
  $doc = $tw->open($xmlfile, %opts);
  $doc->makeKey('bx0doc');
  #$doc->makeKey('all');
  $doc->close();

  ##-- perl-only: mark all data as stale & make (should re-make all)
  #$doc = $tw->open($xmlfile, %opts);
  #$doc->remakeKey('all');
  #$doc->close();

  print STDERR ("$0: test_openclose(): done\n");
}
test_openclose('test1.chr.xml');
#test_openclose('ex1.chr.xml');
#test_openclose('../test/ex2.chr.xml');

##----------------------------------------------------------------------
## MAIN
foreach $i (1..3) {
  print STDERR "dummy($i)\n";
}
