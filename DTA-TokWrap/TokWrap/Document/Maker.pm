## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Document.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: document wrapper: pseudo-make

package DTA::TokWrap::Document::Maker;
use DTA::TokWrap::Version;
use DTA::TokWrap::Document;
use DTA::TokWrap::Utils qw(:time :files);

##==============================================================================
## Globals
##==============================================================================
our @ISA = qw(DTA::TokWrap::Document);

##==============================================================================
## Constructors etc.
##==============================================================================

## $doc = CLASS_OR_OBJECT->new(%args)
##  + additional %args, %$doc:
##    ##-- pseudo-make options
##    force     => \@keys,  ##-- force re-generation of all dependencies for @keys
##    traceMake => $level,  ##-- log-level for makeKey() trace (e.g. 'debug'; default=undef (none))
##    traceGen  => $level,  ##-- log-level for genKey() trace (e.g. 'trace'; default=undef (none))
##    genDummy  => $bool,   ##-- if true, generator will not actually run (a la `make -n`)
##
##    ##-- timestamp data
##    "${key}_stamp"   => $stamp,   ##-- timestamp for data keys; see keyStamp() method
##    "${proc}_stamp0" => $stamp0,  ##-- begin timestamp for process keys
##    "${proc}_stamp"  => $stamp0,  ##-- end timestamp for process keys
#(inherited from DTA::TokWrap::Base via DTA::TokWrap::Document)

## %defaults = CLASS->defaults()
sub defaults {
  return (
	  ##-- inherited defaults
	  $_[0]->SUPER::defaults(),

	  ##-- make options
	  #force => 0,
	  #traceMake => 'trace',
	  #traceGen => 'trace',
	  #genDummy => 0,
	 );
}

## $doc = $doc->init()
##  + set computed defaults
sub init {
  my $doc = shift;

  ##-- inherited initialization
  $doc->SUPER::init() || return undef;

  ##-- defaults: pseudo-make
  if ($doc->{tw}) {
    ##-- propagate from $doc->{tw} to $doc, if available & not overridden
    $doc->{force} = $doc->{tw}{force} if (exists($doc->{tw}{force}) && !exists($doc->{force}));
    $doc->{genDummy} = $doc->{tw}{genDummy} if (exists($doc->{tw}{genDummy}) && !exists($doc->{genDummy}));
  }

  ##-- init: forced remake
  if ($doc->{force}) {
    $doc->{force} = [$doc->{force}] if (!UNIVERSAL::isa($doc->{force},'ARRAY'));
    $doc->forceStale($doc->keyDeps(@{$doc->{force}}),@{$doc->{force}});
  }

  ##-- return
  return $doc;
}

##==============================================================================
## Methods: Pseudo-make: Dependency Tracking
##==============================================================================

##--------------------------------------------------------------
## Methods: Pseudo-make: Dependency Tracking: Initialization

## %KEYGEN = ($dataKey => $generatorSpec, ...)
##  + maps data keys to the generating processes (subroutines, classes, ...)
##  + $generatorSpec is one of:
##     $key      : calls $doc->can($key)->($doc)
##     \&coderef : calls &coderef($doc)
our %KEYGEN =
  (
   xmlfile => sub { $_[0]; },
   (map {$_=>'mkindex'} qw(cxfile sxfile txfile)),
   cxdata => 'loadCxFile',
   bx0doc => 'mkbx0',
   bxdata => 'mkbx',
   bxfile  => 'saveBxFile',
   txtfile => 'saveTxtFile',
   tokdata => 'tokenize',
   tokfile => 'saveTokFile',
   xtokdata => 'tok2xml',
   xtokdoc  => 'xtokDoc',
   xtokfile => 'saveXtokFile',
   sosdoc => 'sosxml',
   sowdoc => 'sowxml',
   soadoc => 'soaxml',
   sosfile => 'saveSosFile',
   sowfile => 'saveSowFile',
   soafile => 'saveSoaFile',
   sofiles => sub { $_[0]{sofiles}=1; },
   all => sub { $_[0]{all}=1; },
  );

## %KEYDEPS = ($dataKey => \@depsForKey, ...)
##  + hash for document data dependency tracking (pseudo-make)
##  + actually tracked are "${docKey}_stamp" variables,
##    or file modification times (for file keys)
our (%KEYDEPS, %KEYDEPS_0, %KEYDEPS_H, %KEYDEPS_N);

## $cmp = PACKAGE::keycmp($a,$b)
##  + sort comparison function for data keys
sub keycmp {
  return (exists($KEYDEPS_H{$_[0]}{$_[1]}) ? 1
	  : (exists($KEYDEPS_H{$_[1]}{$_[0]}) ? -1
	     : $KEYDEPS_N{$_[0]} <=> $KEYDEPS_N{$_[1]}));
}

BEGIN {
  ##-- create KEYDEPS
  %KEYDEPS_0 = (
		xmlfile => [],  ##-- bottom-out here
		(map {$_ => ['xmlfile']} qw(cxfile txfile sxfile)),
		bx0doc => ['sxfile'],
		bxdata => [qw(bx0doc txfile)],
		(map {$_=>['bxdata']} qw(txtfile bxfile)),
		tokdata => ['txtfile'],
		tokfile => ['tokdata'],
		cxdata => ['cxfile'],
		xtokdata => [qw(cxdata bxdata tokdata)],
		xtokfile => ['xtokdata'],
		xtokdoc => ['xtokdata'],
		(map {$_=>['xtokdoc']} qw(sowdoc sosdoc soadoc)),
		(map {($_."file")=>[$_."doc"]} qw(sow sos soa)),
		sodocs  => [qw(sowdoc sosdoc soadoc)],
		sofiles => [qw(sowfile sosfile soafile)],
		##
		##-- Aliases
		tokXml      => [qw(xtokfile)],
		standoffXml => [qw(sofiles)],
		all         => [qw(xtokfile sofiles)],
	       );
  ##-- expand KEYDEPS: convert to hash
  %KEYDEPS_H = qw();
  my ($key,$deps);
  while (($key,$deps)=each(%KEYDEPS_0)) {
    $KEYDEPS_H{$key} = { map {$_=>undef} @$deps };
  }
  ##-- expand KEYDEPS_H: iterate
  my $changed=1;
  my ($ndeps);
  while ($changed) {
    $changed = 0;
    foreach (values(%KEYDEPS_H)) {
      $ndeps = scalar(keys(%$_));
      @$_{map {keys(%{$KEYDEPS_H{$_}})} keys(%$_)} = qw();
      $changed = 1 if (scalar(keys(%$_)) != $ndeps);
    }
  }
  ##-- expand KEYDEPS: sort
  %KEYDEPS_N = (map {$_=>scalar(keys(%{$KEYDEPS_H{$_}}))} keys(%KEYDEPS_H));
  while (($key,$deps)=each(%KEYDEPS_H)) {
    $KEYDEPS{$key} = [ sort {keycmp($a,$b)} keys(%$deps) ];
  }
}

##--------------------------------------------------------------
## Methods: Pseudo-make: Dependency Tracking: Utils

## @uniqKeys = uniqKeys(@keys)
sub uniqKeys {
  my %known = qw();
  my @uniq  = qw();
  foreach (@_) {
    push(@uniq,$_) if (!exists($known{$_}));
    $known{$_}=undef;
  }
  return @uniq;
}

##--------------------------------------------------------------
## Methods: Pseudo-make: Dependency Tracking: Lookup

## @deps0 = PACKAGE::keyDeps0(@docKeys)
##  + immediate dependencies for @docKeys
sub keyDeps0 {
  return uniqKeys(map { @{$KEYDEPS_0{$_}||[]} } @_);
}

## @deps = PACKAGE::keyDeps(@docKeys)
##  + recursive dependencies for @docKeys
sub keyDeps {
  return uniqKeys(map { @{$KEYDEPS{$_}||[]} } @_);
}

##--------------------------------------------------------------
## Methods: Pseudo-make: Dependency Tracking: Timestamps

## $floating_secs_or_undef = $doc->keyStamp($key)
## #$floating_secs_or_undef = $doc->keyStamp($key, $requireKey)
##  + gets $doc->{"${key}_stamp"} if it exists
##  + implicitly creates $doc->{"${key}_stamp"} for readable files
##  + returned value is (floating point) seconds since epoch
sub keyStamp {
  my ($doc,$key) = @_;
  return $doc->{"${key}_stamp"}
    if (defined($doc->{"${key}_stamp"}));
  return $doc->{"${key}_stamp"} = file_mtime($doc->{$key})
    if ($key =~ m/file$/ && defined($doc->{$key}) && -r $doc->{$key});
  return $doc->{"${key}_stamp"} = timestamp()
    if ($key !~ m/file$/ && defined($doc->{$key}));
  return undef;
  ##--
  #my ($doc,$key,$reqKey) = @_;
  #...
  #return undef
  #  if ($reqKey);
  #return $doc->depStamp($doc->keyDeps0($key));
}

## @newerDeps = $doc->keyNewerDeps($key)
## @newerDeps = $doc->keyNewerDeps($key, $missingDepsAreNewer)
sub keyNewerDeps {
  my ($doc,$key,$reqMissing) = @_;
  my $key_stamp = $doc->keyStamp($key);
  return keyDeps($key) if (!defined($key_stamp));
  my (@newerDeps,$dep_stamp);
  foreach (keyDeps($key)) {
    $dep_stamp = $doc->keyStamp($_);
    push(@newerDeps,$_) if ( defined($dep_stamp) ? $dep_stamp > $key_stamp : $reqMissing );
  }
  return @newerDeps;
}

## $bool = $doc->keyIsCurrent($key)
## $bool = $doc->keyIsCurrent($key, $requireMissingDeps)
##  + returns true iff $key is at least as new as all its
##    dependencies
##  + if $requireMissingDeps is true, missing dependencies
##    are treated as infinitely new (function returns false)
sub keyIsCurrent {
  return !scalar($_[0]->keyNewerDeps(@_[1..$#_]));
}

##--------------------------------------------------------------
## Methods: Pseudo-make: (Re-)generation

## $keyval_or_undef = $doc->genKey($key)
##  + unconditionally (re-)generate a data key (single step only)
sub genKey {
  my ($doc,$key) = @_;
  $doc->vlog($doc->{traceGen},"$doc->{xmlbase}: genKey($key)") if ($doc->{traceGen});
  my $gen = $KEYGEN{$key};
  if (!defined($gen)) {
    $doc->logcarp("$doc->{xmlbase}: genKey($key): no generator defined for key '$key'");
    return undef;
  }
  return $doc->{genDummy} if ($doc->{genDummy});
  if (UNIVERSAL::isa($gen,'CODE')) {
    ##-- CODE-ref
    $gen->($doc) || return undef;
  }
  else {
    ##-- default: string
    $doc->can($gen)->($doc) || return undef;
  }
  return $doc->{$key};
}

## $keyval_or_undef = $doc->makeKey($key)
## $keyval_or_undef = $doc->makeKey($key,\%queued)
##  + conditionally (re-)generate a data key, checking dependencies
sub makeKey {
  my ($doc,$key) = @_;
  $doc->vlog($doc->{traceMake},"$doc->{xmlbase}: makeKey($key)") if ($doc->{traceMake});
  return $doc->{$key} if ($doc->keyIsCurrent($key));
  foreach ($doc->keyDeps0($key)) {
    $doc->makeKey($_) if (!defined($doc->{"${_}_stamp"}) || !$doc->keyIsCurrent($_));
  }
  return $doc->genKey($key) if (!$doc->keyIsCurrent($key));
}

## undef = $doc->forceStale(@keys)
##  + forces all keys @keys to be considered stale by setting $doc->{"${key}_stamp"}=-$ix,
##    where $ix is the index of $key in the dependency-sorted list
##  + you can use the $doc->keyDeps() method to get a list of all dependencies
##  + in particular, using $doc->keyDeps('all') should mark all keys as stale
sub forceStale {
  my $doc = shift;
  my @keys = sort {keycmp($a,$b)} @_;
  foreach (0..$#keys) {
    $doc->{"$keys[$_]_stamp"} = -$_-1;
  }
  return $doc;
}

## $keyval_or_undef = $doc->remakeKey($key)
##  + unconditionally (re-)generate a data key and all its dependencies
sub remakeKey {
  my ($doc,$key) = @_;
  #$doc->genKey($_) foreach ($doc->keyDeps($key));
  #return $doc->genKey($key);
  ##--
  $doc->vlog($doc->{traceMake},"$doc->{xmlbase}: makeKey($key)") if ($doc->{traceMake});
  $doc->forceStale($doc->keyDeps($key),$key);
  return $doc->makeKey($key);
}



1; ##-- be happy
