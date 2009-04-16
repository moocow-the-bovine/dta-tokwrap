## -*- Mode: CPerl -*-

## File: DTA::TokWrap::DocParser.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: parser for input documents

package DTA::TokWrap::DocParser;
use Carp;
use IO::File;
use XML::Parser;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw();

##-- per-parse globals (NOT thread-safe!)

our ($docname); ##-- name for document
our ($xmlbuf);  ##-- $docxml: xml string buffer
our ($txtbuf);  ##-- $doctxt: text string buffer
our ($txtpos);  ##-- $txtpos: byte position in text buffer
our (@stack);   ##-- @stack: stack of currently open elements
our ($cbuf);    ##-- buffer for contents of current <c> element
our ($clen);    ##-- length of $cbuf (in bytes)
our ($cbyte);   ##-- byte offset (in XML stream) of start of current <c> element
our ($cnum);    ##-- $cnum: global index of <c> element (number of elts read so far)

our ($xc2xb);   ##-- 'xml <c> to xml byte':  vec($xc2xb, $cnum, 32) == $byte_offset_of_celt_in_xmlbuf     ; packas='N'
our ($xc2tb);   ##-- 'xml <c> to text byte': vec($xc2tb, $cnum, 32) == $byte_offset_celt_text_in_txtbuf   ; packas='N'
our ($xc2tl);   ##-- 'xml <c> to text len':  vec($xc2tl, $cnum,  8) == $byte_length_of_celt_text_in_txtbuf; packas='C'


##==============================================================================
## Constructors etc.
##==============================================================================

## $dp = CLASS_OR_OBJECT->new(%opts)
## + %opts, %$dp:
##   (
##    xopt => \%xopts,   ##-- options to XML::Parser->new()
##    xprs => $xprs,     ##-- underlying XML::Parser object
##   )
sub new {
  my $that = shift;
  my $dp = bless({
		   ##-- Underlying expat parser
		   #xprs => XML::Parser->new(),  ##-- see reset() method
		   xopt => {
			    ErrorContext => 1,
			    ProtocolEncoding => 'UTF-8',
			    #NoExpand => 1,
			   },

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  $dp->init();
  return $dp;
}

## $dp = $dp->init()
##  + initializes underlying expat object
sub init {
  my $dp = shift;
  $dp->{xprs} = XML::Parser->new(%{$dp->{xopt}}) if (!$dp->{xprs});
  $dp->{xprs}->setHandlers(
			   Init      => \&cb_init,
			   Char      => \&cb_char,
			   Start     => \&cb_start,
			   End       => \&cb_end,
			   Final     => \&cb_final,
			   ##
			   Proc      => \&cb_todefault,
			   Comment   => \&cb_todefault,
			   CdataStart=> \&cb_todefault,
			   CdataEnd  => \&cb_todefault,
			   Unparsed  => \&cb_todefault,
			   Doctype   => \&cb_todefault,
			   XMLDecl   => \&cb_todefault,
			   Default   => \&cb_default,
			  );
  $dp->reset();
  return $dp;
}

##==============================================================================
## Methods: Top-level
##==============================================================================

## $dp = $dp->reset()
##   + resets document-local cached data, preparing $dp to parse another document
sub reset {
  my $dp = shift;
  $xmlbuf = '';
  $txtbuf = '';
  $txtpos = 0;
  @stack  = qw();
  $cbuf = '';
  $clen = 0;
  $cbyte = 0;
  $cnum = 0;
  $xc2xb = '';
  $xc2tb = '';
  $xc2tl  = '';
  return $dp;
}

## $doc = $dp->parse($xml_string_or_fh)
## $doc = $dp->parse($xml_string_or_fh, $srcname)
sub parse {
  my ($dp,$source,$name) = @_;
  $dp->reset();
  $docname = $name;
  return $dp->{xprs}->parse($source);
}

## $doc = $dp->parsefile($doc_filename)
sub parsefile {
  my ($dp,$filename) = @_;
  my $ioh = IO::File->new("<$filename")
    or confess(__PACKAGE__ . "::parsefile(): open failed for '$filename': $!");
  my $rc = $dp->parse($ioh,$filename);
  $ioh->close();
  return $rc;
}


##==============================================================================
## Expat Callbacks
##==============================================================================


## undef = cb_init($expat)
sub cb_init {
  ;
}

## undef = cb_char($expat,$string)
sub cb_char {
  if ($stack[$#stack] eq 'c') {
    $cbuf .= $_[0]->original_string();
  }
  $_[0]->default_current();
}

## undef = cb_start($expat, $elt,%attrs)
sub cb_start {
  push(@stack, $_[1]);
  if ($_[1] eq 'c') {
    ##-- reset buffers
    $cbuf = '';
    $cbyte = $_[0]->current_byte(); ##-- +1?
  }
  $_[0]->default_current();
}

## undef = cb_end($expat, $elt)
sub cb_end {
  pop(@stack);
  if ($_[1] eq 'c') {
    ##-- update indices
    $txtbuf .= $cbuf;
    $clen    = length($cbuf); ##-- bytes::length($cbuf)
    vec($xc2xb, $cnum, 32) = $cbyte;
    vec($xc2tb, $cnum, 32) = $txtpos;
    vec($xc2tl, $cnum,  8) = $clen;
    $txtpos += $clen;
    ++$cnum;
  }
  $_[0]->default_current();
}

## undef = cb_todefault($expat,...)
##  + just passes event on to cb_default()
sub cb_todefault {
  $_[0]->default_current();
}

## undef = cb_default($expat,$string)
sub cb_default {
  $xmlbuf .= $_[0]->original_string();
}

## undef = cb_final($expat)
sub cb_final {
  return DTA::TokWrap::Document->new
    (
     name => $docname,
     xmlbuf => $xmlbuf,
     txtbuf => $txtbuf,
     xc2xb => $xc2xb,
     xc2tb => $xc2tb,
     xc2tl => $xc2tl,
    );
}

1; ##-- be happy

__END__
