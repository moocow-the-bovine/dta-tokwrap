## -*- Mode: CPerl -*-

## File: DTA::TokWrap::tokenize.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: tokenizer: placeholder for tomasoblabla

package DTA::TokWrap::tokenize;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs);

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Base);

##==============================================================================
## Constructors etc.
##==============================================================================

## $td = CLASS_OR_OBJ->new(%args)
##  + %args:
##    (none yet)
sub new {
  my $that = shift;
  confess((ref($that)||$that), "::new(): not yet implemented: use DTA::TokWrap::tokenize::dummy!");
}

## %defaults = CLASS->defaults()
sub defaults {
  my $that = shift;
  return (
	  $that->SUPER::defaults(),
	  ##....
	 );
}

## $td = $td->init()

##==============================================================================
## Methods
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->tokenize($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    txtfile => $txtfile,  ##-- (input) serialized text file (uses $doc->{bxdata} if $doc->{txtfile} is not defined)
##    bxdata  => \@bxdata,  ##-- (input) block data, used to generate $doc->{txtfile} if not present
##    tokdata => $tokdata,  ##-- (output) tokenizer output data (string)
## + may implicitly call $doc->mkbx() and/or $doc->saveTxtFile()
sub tokenize {
  my ($td,$doc) = @_;

  confess((ref($td)||$td), "::tokenize(): not yet implemented: use DTA::TokWrap::tokenize::dummy!");

  #return $doc;
  return undef;
}


1; ##-- be happy

