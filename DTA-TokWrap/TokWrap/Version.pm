## -*- Mode: CPerl -*-
##
## File: DTA::TokWrap::Version.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: package version

package DTA::TokWrap::Version;
use Exporter;
use strict;

##==============================================================================
## Constants
##==============================================================================
our $VERSION = 0.01;
our @ISA = qw();

our @EXPORT = ('$VERSION');
our @EXPORT_OK = @EXPORT;
our %EXPORT_TAGS = (
		    default => \@EXPORT,
		    all     => \@EXPORT_OK,
		   );

1; ##-- be happy

