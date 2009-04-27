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
use DTA::TokWrap::Logger;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:si);
use DTA::TokWrap::Document qw(:tok);
use DTA::TokWrap::Document::Maker;

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
##     ##-- Sub-Processor options
##     inplacePrograms => $bool,      ##-- use in-place programs if available? (default=1)
##     procOpts        => \%opts,     ##-- common options for DTA::TokWrap::Processor sub-classes
##     ##
##     ##-- Document options
##     outdir => $outdir,     ##-- passed to $doc->{outdir}; default='.'
##     tmpdir => $tmpdir,     ##-- passed to $doc->{tmpdir}; default=($ENV{DTATW_TMP}||$ENV{TMP}||$outdir)
##     keeptmp => $bool,      ##-- passed to $doc->{keeptmp}; default=0
##     force   => \@keys,     ##-- passed to $doc->{force}; default=none
##     ##
##     ##-- Processing objects
##     mkindex  => $mkindex,   ##-- DTA::TokWrap::Processor::mkindex object, or option-hash
##     mkbx0    => $mkbx0,     ##-- DTA::TokWrap::Processor::mkbx0 object, or option-hash
##     mkbx     => $mkbx,      ##-- DTA::TokWrap::Processor::mkbx object, or option-hash
##     tokenize => $tok,       ##-- DTA::TokWrap::Processor::tokenize object, subclass object, or option-hash
##     tok2xml  => $tok2xml,   ##-- DTA::TokWrap::Processor::tok2xml object, or option-hash
##     standoff => $standoff,  ##-- DTA::TokWrap::Processor::standoff object, or option-hash
##     ##
##     ##-- Profiling information (set on $doc->close())
##     ##   + pseudo-processor '' represents all processor for TokWrap object
##     profile => {
##       ${proc} => {
##         ndocs => $ndocs,          ##-- total number of documents processed by ${proc} (if known)
##         ntoks => $ntoks,          ##-- total number of tokens processed by ${proc} (if known)
##         nxbytes => $nxbytes,      ##-- total number of source XML bytes processed by ${proc} (if known)
##         elapsed => $secs,         ##-- total number of seconds spent in processor ${proc}
##         laststamp => $stamp,      ##-- last end stamp for ${proc}
##       },
##     },
##    )

## %defaults = CLASS->defaults()
sub defaults {
  return (
	  ##-- General options
	  inplacePrograms => 1,
	  #procOpts => {},
	  ##
	  ##-- Document options
	  outdir => '.',
	  tmpdir => ($ENV{DTATW_TMP}||$ENV{TMP}),
	  keeptmp => 0,
	  #force  => undef,
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
		  mkindex => {inplace=>$tw->{inplacePrograms}},
		  mkbx0 => {inplace=>$tw->{inplacePrograms}},
		  tokenize => {inplace=>$tw->{inplacePrograms}},
		  ALL => ($tw->{procOpts}||{}),
		 );
  my ($class,%newopts);
  foreach (qw(mkindex mkbx0 mkbx tokenize tok2xml standoff)) {
    next if (UNIVERSAL::isa($tw->{$_},"DTA::TokWrap::Processor::$_"));
    $class   = $_ eq 'tokenize' ? $TOKENIZE_CLASS : "DTA::TokWrap::Processor::$_";
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

## $doc = $CLASS_OR_OBJECT->open($xmlfile,%docNewOptions)
##  + wrapper for DTA::TokWrap::Document->open($xmlfile,tw=>$tw,%docNewOptions)
sub open {
  my $tw = shift;
  $tw = $tw->new() if (!ref($tw));
  return DTA::TokWrap::Document->open($_[0], tw=>$tw, @_[1..$#_]);
}

## $bool = $tw->close($doc)
##  + Really just a wrapper for $doc->close()
sub close {
  $_[1]{tw} = $_[0];
  $_[1]->close();
}

##==============================================================================
## Methods: Document Processing
##  + nothing here (yet); see DTA::TokWrap::Document e.g. $doc->makeKey()
##==============================================================================

##==============================================================================
## Methods: Profiling
##==============================================================================

## undef = $tw->logProfile($logLevel)
sub logProfile {
  my ($tw,$level) = @_;
  return if (!$level);
  my $logstr = "Summary:";
  my $profh = $tw->{profile};
  #my @procs = (qw(mkindex mkbx0 mkbx tokenize tok2xml sowxml soaxml sosxml),'');
  my @procs = (
	       sort {
		 (
		  (($profh->{$a}{laststamp}||0) <=> ($profh->{$b}{laststamp}||0))
		  ||
		  ($a cmp $b)
		 )
	       } keys(%{$tw->{profile}})
	      );
  my $format = "\n%9s: %4d doc, %7stok, %7sbyte in %7ssec: %7stok/sec ~ %7sbyte/sec";
  my ($proc,$prof,$elapsed,$toksPerSec,$xbytesPerSec);
  foreach $proc (@procs) {
    $prof         = $profh->{$proc};
    $elapsed      = ($prof->{elapsed}||0);
    $toksPerSec   = $elapsed > 0 ? sistr((($prof->{ntoks}||0)/$elapsed),'f','.1') : 'inf  ';
    $xbytesPerSec = $elapsed > 0 ? sistr((($prof->{nxbytes}||0)/$elapsed),'f','.1') : 'inf  ';
    $logstr .= sprintf($format,
		       ($proc eq '' ? 'TOTAL' : $proc),
		       ($prof->{ndocs}||0),
		       sistr(($prof->{ntoks}||0),'f','.1'),
		       sistr(($prof->{nxbytes}||0),'f','.1'),
		       sistr($elapsed, 'f', '.1'),
		       $toksPerSec,
		       $xbytesPerSec);
  }
  $tw->vlog($level,$logstr);
}

1; ##-- be happy
