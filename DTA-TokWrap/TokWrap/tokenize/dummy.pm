## -*- Mode: CPerl -*-

## File: DTA::TokWrap::tokenize::dummy.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: dtatw-tokenize-dummy

package DTA::TokWrap::tokenize::dummy;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :slurp);
use DTA::TokWrap::tokenize;

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
##    tokenize => $path_to_dtatw_tokenize, ##-- default: search
##    inplace  => $bool,                   ##-- prefer in-place programs for search?

## %defaults = CLASS->defaults()
sub defaults {
  my $that = shift;
  return (
	  $that->SUPER::defaults(),
	  tokenize=>undef,
	  inplace=>1,
	 );
}

## $td = $td->init()
sub init {
  my $td = shift;

  ##-- search for tokenizer program
  if (!defined($td->{tokenize})) {
    $td->{tokenize} = path_prog('dtatw-tokenize-dummy',
				prepend=>($td->{inplace} ? ['.','../src'] : undef),
				warnsub=>\&croak,
			       );
  }

  return $td;
}

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

  ##-- sanity check(s)
  $td = $td->new if (!ref($td));
  confess(ref($td), "::tokenize($doc->{xmlfile}): no dtatw-tokenize-dummy program") if (!$td->{tokenize});
  $doc->saveTxtFile() if (!$doc->{txtfile} || !-r $doc->{txtfile});
  confess(ref($td), "::tokenize($doc->{xmlfile}): no .txt file defined") if (!defined($doc->{txtfile}));
  confess(ref($td), "::tokenize($doc->{xmlfile}): .txt file '$doc->{txtfile}' not readable") if (!-r $doc->{txtfile});

  ##-- run program
  $doc->{tokdata} = '';
  my $cmdfh = IO::File->new("'$td->{tokenize}' '$doc->{txtfile}'|")
    or confess(ref($td), "::tokenize($doc->{xmlfile}): open failed for pipe from '$td->{tokenize}': $!");
  slurp_fh($cmdfh, \$doc->{tokdata});
  $cmdfh->close();

  return $doc;
}


1; ##-- be happy

