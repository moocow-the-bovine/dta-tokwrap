## -*- Mode: CPerl -*-

## File: DTA::TokWrap.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: top level

package DTA::TokWrap;
use Time::HiRes ('tv_interval','gettimeofday');
use Carp;
use strict;

##-- sub-modules
use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Document qw(:tok);

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Base);

##==============================================================================
## Constructors etc.
##==============================================================================

## $tw = CLASS_OR_OBJ->new(%args)
##  + %args, %$tw:
##    (
##     ##-- General options
##     inplace => $bool,      ##-- use in-place programs if available? (default=1)
##     force   => $bool,      ##-- force re-generation of all dependencies in 'makeX()' subs
##     ##
##     ##-- Document options
##     outdir => $outdir,     ##-- passed to $doc->{outdir}; default='.'
##     tmpdir => $tmpdir,     ##-- passed to $doc-{tmpdir}; default=($ENV{DTATW_TMP}||$ENV{TMP}||$outdir)
##     keeptmp => $bool,      ##-- passed to $doc->{keeptmp}; default=0
##     ##
##     ##-- Processing objects
##     mkindex  => $mkindex,   ##-- DTA::TokWrap::mkindex object, or option-hash
##     mkbx0    => $mkbx0,     ##-- DTA::TokWrap::mkbx0 object, or option-hash
##     mkbx     => $mkbx,      ##-- DTA::TokWrap::mkbx object, or option-hash
##     tokenize => $tok,       ##-- DTA::TokWrap::tokenize object, subclass object, or option-hash
##     tok2xml  => $tok2xml,   ##-- DTA::TokWrap::tok2xml object, or option-hash
##     standoff => $standoff,  ##-- DTA::TokWrap::standoff object, or option-hash
##    )

## %defaults = CLASS->defaults()
sub defaults {
  return (
	  ##-- General options
	  inplace => 1,
	  ##
	  ##-- Document options
	  outdir => '.',
	  tmpdir => ($ENV{DTATW_TMP}||$ENV{TMP}),
	  keeptmp => 0,
	  ##
	  ##-- Processing objects
	  mkindex => undef,
	  mkbx0 => undef,
	  mkbx => undef,
	  tokenize => undef,
	  tok2xml => undef,
	  standoff => undef,
	 );
}

## $tw = $tw->init()
sub init {
  my $tw = shift;

  ##-- Defaults: Document options
  $tw->{outdir} = '.' if (!$tw->{outdir});
  $tw->{tmpdir} = $tw->{outdir} if (!$tw->{tmpdir});

  ##-- Defaults: Processing objects
  my %key2opts = (
		  mkindex => {inplace=>$tw->{inplace}},
		  mkbx0 => {inplace=>$tw->{inplace}},
		  tokenize => {inplace=>$tw->{inplace}},
		  ALL => {},
		 );
  my ($class,%newopts);
  foreach (qw(mkindex mkbx0 mkbx tokenize tok2xml standoff)) {
    next if (UNIVERSAL::isa($tw->{$_},"DTA::TokWrap::$_"));
    $class   = $_ eq 'tokenize' ? $TOKENIZE_CLASS : "DTA::TokWrap::$_";
    %newopts = (%{$key2opts{ALL}}, ($key2opts{$_} ? %{$key2opts{$_}} : qw()));
    if (UNIVERSAL::isa($tw->{$_},'ARRAY')) {
      $tw->{$_} = $class->new(%newopts, @{$tw->{$_}});
    } elsif (UNIVERSAL::isa($tw->{$_},'HASH')) {
      $tw->{$_} = $class->new(%newopts, %{$tw->{$_}});
    } else {
      $tw->{$_} = $class->new(%newopts);
    }
  }

  ##-- return
  return $tw;
}

##==============================================================================
## Methods: Document pseudo-I/O
##==============================================================================

## $doc = $tw->open($xmlfile,%docNewOptions)
##  + %docNewOptions: see DTA::TokWrap::Document::new()
##  + additionally sets $doc->{tw} = $tw
sub open {
  my ($tw,$xmlfile,@opts) = @_;
  return DTA::TokWrap::Document->open($xmlfile, tw=>$tw, @opts);
}

## $bool = $tw->close($doc)
##  + closes a document
##  + $doc will be practially unuseable after this call (reset to defaults)
##  + unlinks any temporary files in $doc unless $tw->{keeptmp} is true
##    - all %$doc keys ending in 'file' are considered 'temporary' files, except:
##      xmlfile, xtokfile, sosfile, sowfile, soafile
sub close {
  my ($tw,$doc) = @_;

  ##-- unlink temps
  my $rc = 1;
  if (!$tw->{keeptmp}) {
    my %notmpkeys = map {$_=>undef} qw(xmlfile xtokfile sosfile sowfile soafile);
    foreach (
	     grep { $_ =~ m/^$doc->{tmpdir}\// }
	     map { $doc->{$_} }
	     grep { $_ =~ /file$/ && !exists($notmpkeys{$_}) }
	     keys(%$doc)
	    )
      {
	$rc=0 if (!unlink($_));
      }
  }

  ##-- drop $doc references
  %$doc = (ref($doc)||$doc)->defaults();
  return $rc;
}

##==============================================================================
## Methods: Document Processing
##==============================================================================


##--------------------------------------------------------------
## Methods: Document Processing: Low-level
##  + these methods additionally set $doc->{"${methodname}_stamp"} to a Time::HiRes [gettimeofday] value

## $doc_or_undef = $tw->mkindex($doc)
sub mkindex { return $_[0]{mkindex}->mkindex($_[1]); }

## $doc_or_undef = $tw->mkbx0($doc)
sub mkbx0 { $_[0]{mkbx0}->mkbx0($_[1]); }

## $doc_or_undef = $tw->mkbx($doc)
sub mkbx { $_[0]{mkbx}->mkbx($_[1]); }

## $doc_or_undef = $tw->tokenize($doc)
sub tokenize { $_[0]{tokenize}->tokenize($_[1]); }

## $doc_or_undef = $tw->tok2xml($doc)
sub tok2xml { $_[0]{tok2xml}->tok2xml($_[1]); }

## $doc_or_undef = $tw->sosxml($doc)
sub sosxml { $_[0]{standoff}->sosxml($_[1]); }

## $doc_or_undef = $tw->sowxml($doc)
sub sowxml { $_[0]{standoff}->sowxml($_[1]); }

## $doc_or_undef = $tw->soaxml($doc)
sub soaxml { $_[0]{standoff}->soaxml($_[1]); }

## $doc_or_undef = $tw->standoff($doc)
sub standoff { $_[0]{standoff}->standoff($_[1]); }

##--------------------------------------------------------------
## Methods: Document Processing: Standoff XML

## $doc_or_undef = $tw->makeStandoffDocs($doc)
##  + ensures that in-memory standoff XML documents @$doc{qw(sosdoc sowdoc soadoc)} exist
sub makeStandoffDocs {
  my ($tw,$doc) = shift;
  foreach (qw(sosdoc sowdoc soadoc)) {
    return undef if (!$doc->makeKey($_));
  }
  return $doc;
}

## $doc_or_undef = $tw->makeStandoffFiles($doc)
##  + ensures that standoff XML files for $doc are up-to-date
sub makeStandoffFiles {
  my ($tw,$doc) = shift;
  foreach (qw(sosfile sowfile soafile)) {
    return undef if (!$doc->makeKey($_));
  }
  return $doc;
}


1; ##-- be happy
