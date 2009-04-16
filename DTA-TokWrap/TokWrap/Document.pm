## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Document.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: document wrapper

package DTA::TokWrap::Document;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw();

##==============================================================================
## Constructors etc.
##==============================================================================

## $doc = CLASS_OR_OBJECT->new(%opts)
## + %opts, %$doc:
##   (
##    name   => $docname,   ##-- used for xml:base generation
##    xmlbuf => $xmlbuf,    ##-- buffers raw XML for document
##    txtbuf => $txtbuf,    ##-- buffers text stream for document
##    xc2xb  => $xc2xb,     ##-- 'xml <c> to xml byte':  vec($xc2xb, $cnum, 32) == byte_offset($celt[$cnum]) in $xmlbuf
##    xc2tb  => $xc2tb,     ##-- 'xml <c> to text byte': vec($xc2tb, $cnum, 32) == byte_offset($celt[$cnum]) in $txtbuf
##    xc2tl  => $xc2tl,     ##-- 'xml <c> to text len':  vec($xc2tl, $cnum,  8) == byte_length($celt[$cnum]) in $txtbuf
##   )
sub new {
  my $that = shift;
  my $doc = bless({
		   name => '?',
		   xmlbuf => '',
		   txtbuf => '',
		   xc2xb => '',
		   xc2tb => '',
		   xc2tl => '',

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  return $doc;
}

##==============================================================================
## Methods
##==============================================================================

1; ##-- be happy

__END__
