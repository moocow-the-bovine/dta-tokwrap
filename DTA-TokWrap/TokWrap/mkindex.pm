## -*- Mode: CPerl -*-

## File: DTA::TokWrap::mkindex
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: dtatw-mkindex

package DTA::TokWrap::mkindex;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs);

use File::Basename qw(basename dirname);

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Base);

##==============================================================================
## Constructors etc.
##==============================================================================

## $mi = CLASS_OR_OBJ->new(%args)
##  + %args:
##    mkindex => $path_to_dtatw_mkindex, ##-- default: search
##    inplace => $bool,                  ##-- prefer in-place programs for search?

## %defaults = CLASS->defaults()
sub defaults {
  my $that = shift;
  return (
	  $that->SUPER::defaults(),
	  mkindex=>undef,
	  inplace=>1,
	 );
}

## $mi = $mi->init()
sub init {
  my $mi = shift;

  ##-- search for mkindex program
  if (!defined($mi->{mkindex})) {
    $mi->{mkindex} = path_prog('dtatw-mkindex',
			       prepend=>($mi->{inplace} ? ['.','../src'] : undef),
			       warnsub=>\&croak,
			      );
  }

  return $mi;
}

##==============================================================================
## Methods
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->mkindex($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    xmlfile => $xmlfile, ##-- source XML file
##    cxfile  => $cxfile,  ##-- output character index filename
##    sxfile  => $sxfile,  ##-- output structure index filename
##    txfile  => $txfile,  ##-- output structure index filename
sub mkindex {
  my ($mi,$doc) = @_;

  ##-- sanity check(s)
  $mi = $mi->new if (!ref($mi));
  confess(ref($mi), "::mkindex(): no dtatw-mkindex program") if (!$mi->{mkindex});

  ##-- run program
  my $rc = runcmd($mi->{mkindex}, @$doc{qw(xmlfile cxfile sxfile txfile)});
  croak(ref($mi)."::mkindex() failed for XML document '$doc->{xmlfile}': $!") if ($rc!=0);
  croak(ref($mi)."::mkindex() failed to create output file(s) for '$doc->{xmlfile}'")
    if ( ($doc->{cxfile} && !-e $doc->{cxfile})
	 || ($doc->{sxfile} && !-e $doc->{sxfile})
	 || ($doc->{txfile} && !-e $doc->{txfile}) );

  return $doc;
}


1; ##-- be happy

