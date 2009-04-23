## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor::mkindex
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: dtatw-mkindex

package DTA::TokWrap::Processor::mkindex;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :time);
use DTA::TokWrap::Processor;

use File::Basename qw(basename dirname);

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor);

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
			       warnsub=>sub {$mi->logconfess(@_)},
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
##    mkindex_stamp0 => $f, ##-- (output) timestamp of operation begin
##    mkindex_stamp  => $f, ##-- (output) timestamp of operation end
##    cxfile_stamp   => $f, ##-- (output) timetamp of operation end
##    sxfile_stamp   => $f, ##-- (output) timetamp of operation end
##    txfile_stamp   => $f, ##-- (output) timetamp of operation end
sub mkindex {
  my ($mi,$doc) = @_;

  ##-- log, stamp
  $mi->vlog($mi->{traceLevel},"mkindex($doc->{xmlbase})");
  $doc->{mkindex_stamp0} = timestamp(); ##-- stamp

  ##-- sanity check(s)
  $mi = $mi->new if (!ref($mi));
  $mi->logconfess("mkindex($doc->{xmlbase}): no dtatw-mkindex program") if (!$mi->{mkindex});
  $mi->logconfess("mkindex($doc->{xmlbase}): XML source file not readable") if (!-r $doc->{xmlfile});

  ##-- run program
  my $rc = runcmd($mi->{mkindex}, @$doc{qw(xmlfile cxfile sxfile txfile)});
  $mi->logconfess(ref($mi)."::mkindex($doc->{xmlbase}) mkindex program failed: $!") if ($rc!=0);
  $mi->logconfess(ref($mi)."::mkindex($doc->{xmlbase}) failed to create output file(s)")
    if ( ($doc->{cxfile} && !-e $doc->{cxfile})
	 || ($doc->{sxfile} && !-e $doc->{sxfile})
	 || ($doc->{txfile} && !-e $doc->{txfile}) );

  my $stamp = timestamp();
  $doc->{"${_}_stamp"} = $stamp foreach (qw(mkindex cxfile sxfile txfile));
  return $doc;
}


1; ##-- be happy

