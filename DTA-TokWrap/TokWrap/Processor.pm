## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: base class for processor modules

package DTA::TokWrap::Processor;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:time);

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Base);

##==============================================================================
## Constructors etc.
##==============================================================================

## $p = CLASS_OR_OBJ->new(%args)
##  + %args, %$p:
##    traceLevel => $level,   ##-- trace level for DTA::TokWrap::Logger subs

## %defaults = CLASS->defaults()
sub defaults {
  return
    (
     $_[0]->SUPER::defaults,
     traceLevel => 'trace',
     #dummy => 0,
    );
}

## $p = $p->init()

##==============================================================================
## Methods: Document Processing
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->${PROCESS}($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##   (list of input/output keys which ${PROCESS}() sub reads or writes

## $doc_or_undef = $CLASS_OR_OBJECT->process($doc)
## + perform default processing on $doc
## + default implementation calls $CLASS_OR_OBJECT->${BASENAME}($doc) if available,
##   where $BASENAME = ($CLASS=~s/^.*:://); otherwise just returns $doc
sub process {
  my ($p,$doc) = @_;
  (my $base = (ref($p)||$p)) =~ s/^.*:://;
  my $sub = UNIVERSAL::can($p,$base);
  return $sub ? $sub->($p,$doc) : $doc;
}

##==============================================================================
## Methods: Document Processing
##==============================================================================

1; ##-- be happy

