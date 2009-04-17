## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Base
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: base class

package DTA::TokWrap::Base;
use DTA::TokWrap::Version;

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw();

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH:
##    {
##     %args,
##    }
##  + calls $obj->init() after instantiation
sub new {
  my $that = shift;
  my $obj = bless({
		   ##-- defaults
		   $that->defaults(),

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  return $obj->init();
}

## %defaults = CLASS_OR_OBJ->defaults()
##  + called by constructor
sub defaults {
  return qw();
}

## $obj = $obj->init()
##  + dummy method
sub init {
  return $_[0];
}

##==============================================================================
## Methods
##==============================================================================

#(nothing here)

1; ##-- be happy

