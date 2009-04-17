## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Document.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: document wrapper

package DTA::TokWrap::Document;
use DTA::TokWrap::Base;
use DTA::TokWrap::Version;
use File::Basename qw(basename dirname);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================
our @ISA = qw(DTA::TokWrap::Base);

##==============================================================================
## Constructors etc.
##==============================================================================

## $doc = CLASS_OR_OBJECT->new(%args)
## + %args, %$doc
##   (
##    ##-- Source data
##    xmlfile => $xmlfile,  ##-- source filename
##    xmlbase => $xmlbase,  ##-- xml:base for generated files (default=basename($xmlfile))
##
##    ##-- generated data (common)
##    outdir => $outdir,    ##-- output directory for generated data (default=.)
##    outbase => $filebase, ##-- output basename (default=`basename $xmlbase .xml`)
##
##    ##-- mkindex data (see DTA::TokWrap::mkindex)
##    cxfile => $cxfile,    ##-- character index file (default="$outbase.cx")
##    sxfile => $sxfile,    ##-- structure index file (default="$outbase.sx")
##    txfile => $txfile,    ##-- raw text index file (default="$outbase.tx")
##
##    ##-- mkbx0 data (see DTA::TokWrap::mkbx0)
##    bx0doc  => $bx0doc,   ##-- pre-serialized block-index XML::LibXML::Document
##    bx0file => $bx0file,  ##-- pre-serialized block-index file (default="$outbase.bx0"; optional)
##   )
#(inherited from DTA::TokWrap::Base)

## %defaults = CLASS->defaults()
sub defaults {
  return (
	  ##-- source data
	  xmlfile => undef,
	  xmlbase => undef,

	  ##-- generated data (common)
	  outdir => '.',
	  outbase => undef,

	  ##-- mkindex data
	  cxfile => undef,
	  sxfile => undef,
	  txfile => undef,

	  ##-- mkbx0 data
	  bx0doc  => undef,
	  bx0file => undef,
	 );
}

## $doc = $doc->init()
##  + set computed defaults
sub init {
  my $doc = shift;

  ##-- defaults: source data
  $doc->{xmlfile} = '-' if (!defined($doc->{xmlfile})); ##-- this should really be required
  $doc->{xmlbase} = basename($doc->{xmlfile}) if (!defined($doc->{xmlbase}));

  ##-- defaults: generated data (common)
  ($doc->{outbase} = basename($doc->{xmlbase})) =~ s/\.xml$//i if (!$doc->{outbase});

  ##-- defaults: mkindex data
  $doc->{cxfile} = $doc->{outdir}.'/'.$doc->{outbase}.".cx" if (!$doc->{cxfile});
  $doc->{sxfile} = $doc->{outdir}.'/'.$doc->{outbase}.".sx" if (!$doc->{sxfile});
  $doc->{txfile} = $doc->{outdir}.'/'.$doc->{outbase}.".tx" if (!$doc->{txfile});

  ##-- defaults: mkbx0 data
  #$doc->{bx0doc} = undef;
  $doc->{bx0file} = $doc->{outdir}.'/'.$doc->{outbase}.".bx0" if (!$doc->{bx0file});

  ##-- return
  return $doc;
}

##==============================================================================
## Methods
##==============================================================================

1; ##-- be happy

__END__
