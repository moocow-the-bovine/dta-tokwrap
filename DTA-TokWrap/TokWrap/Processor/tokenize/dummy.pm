## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor::tokenize::dummy.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: dtatw-tokenize-dummy

package DTA::TokWrap::Processor::tokenize::dummy;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :slurp :time);
use DTA::TokWrap::Processor;
use DTA::TokWrap::Processor::tokenize;

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor);

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
				warnsub=>sub {$td->logconfess(@_)},
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
##    tokenize_stamp0 => $f, ##-- (output) timestamp of operation begin
##    tokenize_stamp  => $f, ##-- (output) timestamp of operation end
##    tokdata_stamp => $f,   ##-- (output) timestamp of operation end
## + may implicitly call $doc->mkbx() and/or $doc->saveTxtFile()
sub tokenize {
  my ($td,$doc) = @_;

  ##-- log, stamp
  $td->info("tokenize($doc->{xmlbase})");
  $doc->{tokenize_stamp0} = timestamp();

  ##-- sanity check(s)
  $td = $td->new if (!ref($td));
  $td->logconfess("tokenize($doc->{xmlbase}): no dtatw-tokenize-dummy program")
    if (!$td->{tokenize});
  #$doc->saveTxtFile() if (!$doc->{txtfile} || !-r $doc->{txtfile});
  $td->logconfess("tokenize($doc->{xmlbase}): no .txt file defined")
    if (!defined($doc->{txtfile}));
  $td->logconfess("tokenize($doc->{xmlbase}): .txt file '$doc->{txtfile}' not readable")
    if (!-r $doc->{txtfile});

  ##-- run program
  $doc->{tokdata} = '';
  my $cmdfh = IO::File->new("'$td->{tokenize}' '$doc->{txtfile}'|")
    or $td->logconfess("tokenize($doc->{xmlbase}): open failed for pipe ('$td->{tokenize}' '$doc->{txtfile}' |): $!");
  slurp_fh($cmdfh, \$doc->{tokdata});
  $cmdfh->close();

  $doc->{tokenize_stamp} = $doc->{tokdata_stamp} = timestamp(); ##-- stamp
  return $doc;
}


1; ##-- be happy

