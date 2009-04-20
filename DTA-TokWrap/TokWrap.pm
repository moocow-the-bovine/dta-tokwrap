## -*- Mode: CPerl -*-

## File: DTA::TokWrap.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: top level

package DTA::TokWrap;
use Carp;
use strict;

##-- sub-modules
use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Document;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Base);

##==============================================================================
## Constructors etc.
##==============================================================================

## $tw = CLASS_OR_OBJ->new(%args)
##  + %args:
##    ...

## $tw = $tw->init()
##(see DTA::TokWrap::Base::init)

##==============================================================================
## Methods
##==============================================================================

1; ##-- be happy

