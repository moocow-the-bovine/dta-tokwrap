## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Document.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: document wrapper

package DTA::TokWrap::Document;
use DTA::TokWrap::Base;
use DTA::TokWrap::Version;
use DTA::TokWrap::Utils qw(:libxml :files :time);
use DTA::TokWrap::mkindex;
use DTA::TokWrap::mkbx0;
use DTA::TokWrap::mkbx;
use DTA::TokWrap::tokenize;
use DTA::TokWrap::tokenize::dummy;
use DTA::TokWrap::tok2xml;
use DTA::TokWrap::standoff;

use Time::HiRes ('tv_interval','gettimeofday');
use File::Basename qw(basename dirname);
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================
our @ISA = qw(DTA::TokWrap::Base Exporter);

## $TOKENIZE_CLASS
##  + default tokenizer class
#our $TOKENIZE_CLASS = 'DTA::TokWrap::tokenize';
our $TOKENIZE_CLASS = 'DTA::TokWrap::tokenize::dummy';

## $CX_ID   : {cxdata} index of id field
## $CX_XOFF : {cxdata} index of XML byte-offset field
## $CX_XLEN : {cxdata} index of XML byte-length field
## $CX_TOFF : {cxdata} index of .tx byte-offset field
## $CX_TLEN : {cxdata} index of .tx byte-length field
## $CX_TEXT : {cxdata} index of text / details field(s)
our ($CX_ID,$CX_XOFF,$CX_XLEN,$CX_TOFF,$CX_TLEN,$CX_TEXT) = (0..5);

our @EXPORT = qw();
our %EXPORT_TAGS = (
		    cx => [qw($CX_ID $CX_XOFF $CX_XLEN $CX_TOFF $CX_TLEN $CX_TEXT)],
		    tok => ['$TOKENIZE_CLASS'],
		   );
$EXPORT_TAGS{all} = [map {@$_} values(%EXPORT_TAGS)];
our @EXPORT_OK = @{$EXPORT_TAGS{all}};

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
##    ##-- generator data (optional)
##    tw => $tw,            ##-- a DTA::TokWrap object storing individual generators
##
##    ##-- generated data (common)
##    outdir => $outdir,    ##-- output directory for generated data (default=.)
##    tmpdir => $tmpdir,    ##-- temporary directory for generated data (default=$ENV{TMP} or $outdir)
##    keeptmp => $bool,     ##-- if true, temporary document-local files will be kept on $doc->close()
##    outbase => $filebase, ##-- output basename (default=`basename $xmlbase .xml`)
##    format => $level,     ##-- default formatting level for XML output
##
##    ##-- mkindex data (see DTA::TokWrap::mkindex)
##    cxfile => $cxfile,    ##-- character index file (default="$tmpdir/$outbase.cx")
##    cxdata => $cxdata,    ##-- character index data (see loadCxFile() method)
##    sxfile => $sxfile,    ##-- structure index file (default="$tmpdir/$outbase.sx")
##    txfile => $txfile,    ##-- raw text index file (default="$tmpdir/$outbase.tx")
##
##    ##-- mkbx0 data (see DTA::TokWrap::mkbx0)
##    bx0doc  => $bx0doc,   ##-- pre-serialized block-index XML::LibXML::Document
##    bx0file => $bx0file,  ##-- pre-serialized block-index XML file (default="$outbase.bx0"; optional)
##
##    ##-- mkbx data (see DTA::TokWrap::mkbx)
##    bxdata  => \@bxdata,  ##-- block-list, see DTA::TokWrap::mkbx::mkbx() for details
##    bxfile  => $bxfile,   ##-- serialized block-index CSV file (default="$outbase.bx"; optional)
##    txtfile => $txtfile,  ##-- serialized & hinted text file (default="$outbase.txt"; optional)
##
##    ##-- tokenize data (see DTA::TokWrap::tokenize, DTA::TokWrap::tokenize::dummy)
##    tokdata => $tokdata,  ##-- tokenizer output data (slurped string)
##    tokfile => $tokfile,  ##-- tokenizer output file (default="$outbase.t"; optional)
##
##    ##-- tokenizer xml data (see DTA::TokWrap::tok2xml)
##    xtokdata => $xtokdata,  ##-- XML-ified tokenizer output data
##    xtokfile => $xtokfile,  ##-- XML-ified tokenizer output file (default="$outbase.t.xml")
##    xtokdoc  => $xtokdoc,   ##-- XML::LibXML::Document for $xtokdata (parsed from string)
##
##    ##-- standoff xml data (see DTA::TokWrap::standoff)
##    sosdoc  => $sosdata,   ##-- XML::LibXML::Document: sentence standoff data
##    sowdoc  => $sowdata,   ##-- XML::LibXML::Document: token standoff data
##    soadoc  => $soadata,   ##-- XML::LibXML::Document: analysis standoff data
##    ##
##    sosfile => $sosfile,   ##-- filename for $sosdoc (implied)
##    sowfile => $sowfile,   ##-- filename for $sowdoc (implied)
##    soafile => $soafile,   ##-- filename for $soadoc (implied)
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
	  tmpdir => ($ENV{DTATW_TMP}||$ENV{TMP}),
	  keeptmp => 0,
	  outbase => undef,
	  format  => 0,

	  ##-- mkindex data
	  cxfile => undef,
	  cxdata => undef,
	  sxfile => undef,
	  txfile => undef,

	  ##-- mkbx0 data
	  bx0doc  => undef,
	  bx0file => undef,

	  ##-- mkbx data
	  bxdata => undef,
	  bxfile => undef,
	  txtfile => undef,

	  ##-- tokenizer data
	  tokdata => undef,
	  tokfile => undef,

	  ##-- tokenizer xml-ified data
	  xtokdata => undef,
	  xtokfile => undef,

	  ##-- standoff data
	  sosdoc => undef,
	  sowdoc => undef,
	  soadoc => undef,
	  ##
	  sosfile => undef,
	  sowfile => undef,
	  soafile => undef,
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
  if ($doc->{tw}) {
    ##-- propagate from $doc->{tw} to $doc, if available
    $doc->{outdir} = $doc->{tw}{outdir};
    $doc->{tmpdir} = $doc->{tw}{tmpdir};
    $doc->{keeptmp} = $doc->{tw}{keeptmp};
  }
  $doc->{outdir} = '.' if (!$doc->{outdir});
  $doc->{tmpdir} = $doc->{outdir} if (!$doc->{tmpdir});

  ##-- defaults: mkindex data
  $doc->{cxfile} = $doc->{tmpdir}.'/'.$doc->{outbase}.".cx" if (!$doc->{cxfile});
  $doc->{sxfile} = $doc->{tmpdir}.'/'.$doc->{outbase}.".sx" if (!$doc->{sxfile});
  $doc->{txfile} = $doc->{tmpdir}.'/'.$doc->{outbase}.".tx" if (!$doc->{txfile});

  ##-- defaults: mkbx0 data
  #$doc->{bx0doc} = undef;
  $doc->{bx0file} = $doc->{tmpdir}.'/'.$doc->{outbase}.".bx0" if (!$doc->{bx0file});

  ##-- defaults: mkbx data
  #$doc->{bxdata}  = undef;
  $doc->{bxfile}  = $doc->{tmpdir}.'/'.$doc->{outbase}.".bx" if (!$doc->{bxfile});
  $doc->{txtfile} = $doc->{tmpdir}.'/'.$doc->{outbase}.".txt" if (!$doc->{txtfile});

  ##-- defaults: tokenizer output data (tokenize)
  #$doc->{tokdata}  = undef;
  $doc->{tokfile}  = $doc->{tmpdir}.'/'.$doc->{outbase}.".t" if (!$doc->{tokfile});

  ##-- defaults: tokenizer xml data (tok2xml)
  #$doc->{xtokdata}  = undef;
  $doc->{xtokfile}  = $doc->{tmpdir}.'/'.$doc->{outbase}.".t.xml" if (!$doc->{xtokfile});

  ##-- defaults: standoff data (standoff)
  #$doc->{sosdoc} = undef;
  #$doc->{sowdoc} = undef;
  #$doc->{soadoc} = undef;
  ##
  $doc->{sosfile} = $doc->{outdir}.'/'.$doc->{outbase}.".s.xml" if (!$doc->{sosfile});
  $doc->{sowfile} = $doc->{outdir}.'/'.$doc->{outbase}.".w.xml" if (!$doc->{sowfile});
  $doc->{soafile} = $doc->{outdir}.'/'.$doc->{outbase}.".a.xml" if (!$doc->{soafile});

  ##-- return
  return $doc;
}

##==============================================================================
## Methods: Pseudo-I/O
##==============================================================================

## $newdoc = CLASS_OR_OBJECT->open($xmlfile,%docNewOptions)
##  + wrapper for CLASS_OR_OBJECT->new()
sub open {
  my ($doc,$xmlfile,@opts) = @_;
  confess(__PACKAGE__, "::open(): could not open '$xmlfile': $!") if (!file_try_open($xmlfile));
  return $doc->new(xmlfile=>$xmlfile,@opts);
}

## $bool = $doc->close()
##  + "closes" document $doc
##  + $doc will be practially unuseable after this call (reset to defaults)
##  + unlinks any temporary files in $doc unless $tw->{keeptmp} is true
##    - all %$doc keys ending in 'file' are considered 'temporary' files, except:
##      xmlfile, xtokfile, sosfile, sowfile, soafile
our (%CLOSE_NOTMPKEYS);
BEGIN { %CLOSE_NOTMPKEYS = map {$_=>undef} qw(xmlfile xtokfile sosfile sowfile soafile); }
sub close {
  my $doc = shift;

  my $rc = 1;
  if (ref($doc) && !$doc->{keeptmp}) {
    ##-- unlink temp files
    foreach (
	     grep { $_ =~ m/^$doc->{tmpdir}\// }
	     map { $doc->{$_} }
	     grep { $_ =~ /file$/ && !exists($CLOSE_NOTMPKEYS{$_}) }
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
## Methods: Dependency Tracking
##==============================================================================

##--------------------------------------------------------------
## Methods: Document Processing: Dependency-tracking

## %KEYGEN = ($dataKey => $generatorSpec, ...)
##  + maps data keys to the generating processes (subroutines, classes, ...)
##  + $generatorSpec is one of:
##     $key      : calls $doc->can($key)->($doc)
##     \&coderef : calls &coderef($doc)
our %KEYGEN =
  (
   xmlfile => sub { $_[0]; },
   (map {$_=>'mkindex'} qw(bxfile cxfile sxfile)),
   cxdata => \&loadCxFile,
   bx0doc => 'mkbx0',
   bxdata => 'mkbx',
   bxfile  => \&saveBxFile,
   txtfile => \&saveTxtFile,
   tokdata => 'tokenize',
   tokfile => \&saveTokFile,
   xtokdata => 'tok2xml',
   xtokdoc  => \&xtokDoc,
   xtokfile => \&saveXtokFile,
   sosdoc => 'sosxml',
   sowdoc => 'sowxml',
   soadoc => 'soaxml',
   sosfile => \&saveSosFile,
   sowfile => \&saveSowFile,
   soafile => \&saveSoaFile,
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
		ALL => ['sofiles'],
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

## @deps = PACKAGE::keyDeps(@docKeys)
sub keyDeps {
  return @{$KEYDEPS{$_[0]}||[]} if ($#_ == 0);
  my %knowndeps = qw();
  my @alldeps   = qw();
  my ($keydeps);
  foreach (@_) {
    $keydeps = $KEYDEPS{$_} || [];
    push(@alldeps, grep {!exists($knowndeps{$_})} @$keydeps);
    @knowndeps{@$keydeps} = qw();
  }
  return @alldeps;
}

## $floating_secs_or_undef = $doc->keyStamp($key)
##  + gets $doc->{"${key}_stamp"} if it exists
##  + implicitly creates $doc->{"${key}_stamp"} for readable files
##  + returned value is (floating point) seconds since epoch
sub keyStamp {
  my ($doc,$key) = @_;
  return $doc->{"${key}_stamp"}
    if (defined($doc->{"${key}_stamp"}));
  return $doc->{"${key}_stamp"} = file_mtime($doc->{$key})
    if ($key =~ /file$/ && defined($doc->{$key}) && -r $doc->{$key});
  return undef;
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
##  + returns true iff $key is newer than all its dependencies
##  + if $requireMissingDeps is true, missing dependencies
##    are treated as infinitely new (function returns false)
sub keyIsCurrent {
  return !scalar($_[0]->keyNewerDeps(@_[1..$#_]));
}

## $keyval_or_undef = $doc->genKey($key)
##  + unconditionally (re-)generate a data key (single step only)
sub genKey {
  my ($doc,$key) = @_;
  my $gen = $KEYGEN{$key};
  if (!defined($gen)) {
    carp(ref($doc), "::genKey(): no generator defined for key '$key'");
    return undef;
  }
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
##  + conditionally (re-)generate a data key, checking dependencies
sub makeKey {
  my ($doc,$key) = @_;
  $doc->makeKey($_) foreach ($doc->keyNewerDeps($key));
  return $doc->genKey($key) if (!$doc->keyIsCurrent($key));
  return $doc->{$key};
}

## undef = $doc->forceStale(@keys)
##  + forces all keys @keys to be considered stale by setting $doc->{"${key}_stamp"}=-$ix,
##    where $ix is the index of $key in the dependency-sorted list
##  + you can use the $doc->keyDeps() method to get a list of all dependencies
##  + in particular, using $doc->keyDeps('ALL') should mark all keys as stale
sub forceStale {
  my $doc = shift;
  my @keys = sort {keycmp($a,$b)} @_;
  foreach (0..$#keys) {
    $doc->{"$keys[$_]_stamp"} = -$_-1;
  }
  return $doc;
}

## $keyval_or_undef = $doc->forceKey($key)
##  + unconditionally (re-)generate a data key and all its dependencies
sub forceKey {
  my ($doc,$key) = @_;
  #$doc->genKey($_) foreach ($doc->keyDeps($key));
  #return $doc->genKey($key);
  ##--
  $doc->forceStale($doc->keyDeps($key),$key);
  return $doc->makeKey($key);
}

##==============================================================================
## Methods: annotation & indexing: low-level generator-subclass wrappers
##==============================================================================

## $doc_or_undef = $doc->mkindex($mkindex)
## $doc_or_undef = $doc->mkindex()
##  + see DTA::TokWrap::mkindex::mkindex()
sub mkindex {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{mkindex}) || 'DTA::TokWrap::mkindex')->mkindex($_[0]);
}

## $doc_or_undef = $doc->mkbx0($mkbx0)
## $doc_or_undef = $doc->mkbx0()
##  + see DTA::TokWrap::mkbx0::mkbx0()
sub mkbx0 {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{mkbx0}) || 'DTA::TokWrap::mkbx0')->mkbx0($_[0]);
}

## $doc_or_undef = $doc->mkbx($mkbx)
## $doc_or_undef = $doc->mkbx()
##  + see DTA::TokWrap::mkbx::mkbx()
sub mkbx {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{mkbx}) || 'DTA::TokWrap::mkbx')->mkbx($_[0]);
}

## $doc_or_undef = $doc->tokenize($tokenize)
## $doc_or_undef = $doc->tokenize()
##  + see DTA::TokWrap::tokenize::tokenize()
##  + default tokenizer class is given by package-global $TOKENIZE_CLASS
sub tokenize {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{tokenize}) || $TOKENIZE_CLASS)->tokenize($_[0]);
}

## $doc_or_undef = $doc->tok2xml($tok2xml)
## $doc_or_undef = $doc->tok2xml()
##  + see DTA::TokWrap::tok2xml::tok2xml()
sub tok2xml {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{tok2xml}) || 'DTA::TokWrap::tok2xml')->tok2xml($_[0]);
}

## $doc_or_undef = $doc->sosxml($so)
## $doc_or_undef = $doc->sosxml()
##  + see DTA::TokWrap::standoff::sosxml()
sub sosxml {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{standoff}) || 'DTA::TokWrap::standoff')->sosxml($_[0]);
}

## $doc_or_undef = $doc->sowxml($so)
## $doc_or_undef = $doc->sowxml()
##  + see DTA::TokWrap::standoff::sowxml()
sub sowxml {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{standoff}) || 'DTA::TokWrap::standoff')->sowxml($_[0]);
}

## $doc_or_undef = $doc->soaxml($so)
## $doc_or_undef = $doc->soaxml()
##  + see DTA::TokWrap::standoff::soaxml()
sub soaxml {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{standoff}) || 'DTA::TokWrap::standoff')->soaxml($_[0]);
}

## $doc_or_undef = $doc->standoff($so)
## $doc_or_undef = $doc->standoff()
##  + wrapper for sosxml(), sowxml(), soaxml()
##  + see DTA::TokWrap::standoff::standoff()
sub standoff {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{standoff}) || 'DTA::TokWrap::standoff')->standoff($_[0]);
}

##==============================================================================
## Methods: Data Munging
##==============================================================================

## $xtokDoc = $doc->xtokDoc(\$xtokdata)
## $xtokDoc = $doc->xtokDoc()
##  + parse \$xtokdata (default: \$doc->{xtokdata}) string into $doc->{xtokdoc}
##  + may call $doc->tok2xml()
sub xtokDoc {
  my ($doc,$xtdatar) = @_;

  ##-- get data
  $xtdatar = \$doc->{xtokdata} if (!$xtdatar);
  if (!$xtdatar || !defined($$xtdatar)) {
    $doc->tok2xml()
      or confess(ref($doc), "::xtokDoc(): tok2xml() failed for document '$doc->{xmlfile}': $!");
    $xtdatar = \$doc->{xtokdata};
  }

  ##-- get xml parser
  my $xmlparser = libxml_parser(keep_blanks=>0);
  my $xtdoc = $doc->{xtokdoc} = $xmlparser->parse_string($$xtdatar)
    or confess(ref($doc), "::xtokDoc(): could not parse t.xml data as XML: $!");

  $doc->{xtokdoc_stamp} = timestamp(); ##-- stamp
  return $doc->{xtokdoc};
}

##==============================================================================
## Methods: I/O
##==============================================================================

##----------------------------------------------------------------------
## Methods: I/O: input

## $cxdata_or_undef = $doc->loadCxFile($filename_or_fh)
## $cxdata_or_undef = $doc->loadCxFile()
##  + loads $doc->{cxdata} from $filename_or_fh (default=$doc->{cxfile})
##  + may implicitly call $doc->mkindex()
##  + $doc->{cxdata} = [ $cx0, ... ]
##    - where each $cx = [ $id, $xoff,$xlen, $toff,$tlen, $text ]
##    - globals $CX_ID, $CX_XOFF, etc. are indices for $cx arrays
sub loadCxFile {
  my ($doc,$file) = @_;

  ##-- get file
  $file = $doc->{cxfile} if (!$file);
  if (!$file || (!ref($file) && !-r $file)) {
    $doc->mkindex()
      or confess(ref($doc), "::loadCxFile(): mkindex()() failed for document '$doc->{xmlfile}': $!");
    $file = $doc->{cxfile};
  }

  my $cx = $doc->{cxdata} = [];
  my $fh = ref($file) ? $file : IO::File->new("<$file");
  confess(ref($doc), "::loadCxFile(): open failed for .cx file '$file': $!") if (!$fh);
  $fh->binmode() if (!ref($file));
  while (<$fh>) {
    chomp;
    next if (/^%%/ || /^\s*$/);
    push(@$cx, [split(/\t/,$_)]);
  }
  $fh->close() if (!ref($file));

  $_[0]{cxdata_stamp} = Time::HiRes::time();
  return $cx;
}

##----------------------------------------------------------------------
## Methods: I/O: output

## $file_or_undef = $doc->saveBx0File($filename_or_fh,$bx0doc,%opts)
## $file_or_undef = $doc->saveBx0File($filename_or_fh)
## $file_or_undef = $doc->saveBx0File()
##  + %opts:
##     format => $level,  ##-- do output formatting (default=$doc->{format})
##  + $bx0doc defaults to $doc->{bx0doc}
##  + $filename_or_fh defaults to $doc->{bx0file}="$doc->{outdir}/$doc->{outbase}.bx0"
##  + sets $doc->{bx0file} if a filename is passed or defaulted
##  + may implicitly call $doc->mkbx0() (if $bx0doc and $doc->{bxdata} are both false)
##  + sets $doc->{bx0file_stamp}
sub saveBx0File {
  my ($doc,$file,$bx0doc,%opts) = @_;

  ##-- get bx0doc
  $bx0doc = $doc->{bx0doc} if (!$bx0doc);
  if (!$bx0doc) {
    $doc->mkbx0()
      or confess(ref($doc), "::saveBx0File(): mkbx0() failed for document '$doc->{xmlfile}': $!");
    $bx0doc = $doc->{bx0doc};
  }

  ##-- get file
  $file = $doc->{bx0file} if (!defined($file));
  $file = "$doc->{outdir}/$doc->{outbase}.bx0" if (!defined($file));
  $doc->{bx0file} = $file if (!ref($file));

  ##-- actual save
  my $format = (exists($opts{format}) ? $opts{format} : $doc->{format})||0;
  if (ref($file)) {
    $bx0doc->toFh($format);
  } else {
    $bx0doc->toFile($format);
  }

  $doc->{bx0file_stamp} = timestamp(); ##-- stamp
  return $file;
}

## $file_or_undef = $doc->saveBxFile($filename_or_fh,\@blocks)
## $file_or_undef = $doc->saveBxFile($filename_or_fh)
## $file_or_undef = $doc->saveBxFile()
##  + \@blocks defaults to $doc->{bxdata}
##  + $filename_or_fh defaults to $doc->{bxfile}="$doc->{outdir}/$doc->{outbase}.bx"
##  + may implicitly call $doc->mkbx() (if \@blocks and $doc->{bxdata} are both false)
##  + sets $doc->{bxfile_stamp}
sub saveBxFile {
  my ($doc,$file,$bxdata) = @_;

  ##-- get bxdata
  $bxdata = $doc->{bxdata} if (!$bxdata);
  if (!$bxdata) {
    $doc->mkbx()
      or confess(ref($doc), "::saveBxFile(): mkbx() failed for document '$doc->{xmlfile}': $!");
    $bxdata = $doc->{bxdata};
  }

  ##-- get file
  $file = $doc->{bxfile} if (!defined($file));
  $file = "$doc->{outdir}/$doc->{outbase}.bx" if (!defined($file));
  $doc->{bxfile} = $file if (!ref($file));

  ##-- get filehandle & print
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  die(ref($doc), "::saveBxFile(): open failed for output file '$file': $!") if (!$fh);
  $fh->print(
	      "%% XML block list file generated by ", __PACKAGE__, "::saveBxFile()\n",
	      "%% Original source file: $doc->{xmlfile}\n",
	      "%%======================================================================\n",
	      "%% \$KEY\$\t\$ELT\$\t\$XML_OFFSET\$\t\$XML_LENGTH\$\t\$TX_OFFSET\$\t\$TX_LEN\$\t\$TXT_OFFSET\$\t\$TXT_LEN\$\n",
	      (map {join("\t", @$_{qw(key elt xoff xlen toff tlen otoff otlen)})."\n"} @$bxdata),
	    );
  $fh->close() if (!ref($file));

  $doc->{bxfile_stamp} = timestamp(); ##-- stamp
  return $file;
}

## $file_or_undef = $doc->saveTxtFile($filename_or_fh,\@blocks,%opts)
## $file_or_undef = $doc->saveTxtFile($filename_or_fh)
## $file_or_undef = $doc->saveTxtFile()
##  + %opts:
##      debug=>$bool,  ##-- if true, debugging text will be printed (and saveBxFile() offsets will be wrong)
##  + $filename_or_fh defaults to $doc->{txtfile}="$doc->{outdir}/$doc->{outbase}.txt"
##  + \@blocks defaults to $doc->{bxdata}
##  + may implicitly call $doc->mkbx() (if \@blocks is unspecified and $doc->{bxdata} is false)
##  + sets $doc->{txtfile_stamp}
sub saveTxtFile {
  my ($doc,$file,$bxdata,%opts) = @_;

  ##-- get options
  my $debug_txt = $opts{debug};

  ##-- get bxdata
  $bxdata = $doc->{bxdata} if (!$bxdata);
  if (!$bxdata) {
    $doc->mkbx()
      or confess(ref($doc), "::saveTxtFile(): mkbx() failed for document '$doc->{xmlfile}': $!");
    $bxdata = $doc->{bxdata};
  }

  ##-- get file
  $file = $doc->{txtfile} if (!defined($file));
  $file = "$doc->{outdir}/$doc->{outbase}.txt" if (!defined($file));
  $doc->{txtfile} = $file if (!ref($file));

  ##-- get filehandle & print
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  $fh->binmode() if (!ref($file));
  $fh->print(
	     map {
	       (($debug_txt ? "[$_->{key}:$_->{elt}]\n" : qw()),
		$_->{otext},
		($debug_txt ? "\n[/$_->{key}:$_->{elt}]\n" : qw()),
	       )
	     } @$bxdata
	    );
  $fh->print("\n"); ##-- always terminate text file with a newline
  $fh->close() if (!ref($file));

  $doc->{txtfile_stamp} = timestamp(); ##-- stamp
  return $file;
}

## $file_or_undef = $doc->saveTokFile($filename_or_fh,\$tokdata)
## $file_or_undef = $doc->saveTokFile($filename_or_fh)
## $file_or_undef = $doc->saveTokFile()
##  + $filename_or_fh defaults to $doc->{tokfile}="$doc->{outdir}/$doc->{outbase}.t"
##  + \$tokdata defaults to \$doc->{tokdata}
##  + may implicitly call $doc->tokenize() (if \$tokdata and $doc->{tokdata} are both undefined)
##  + sets $doc->{tokfile_stamp}
sub saveTokFile {
  my ($doc,$file,$tokdatar) = @_;

  ##-- get data
  $tokdatar = \$doc->{tokdata} if (!$tokdatar);
  if (!$tokdatar || !defined($$tokdatar)) {
    $doc->tokenize()
      or confess(ref($doc), "::saveTokFile(): tokenize() failed for document '$doc->{xmlfile}': $!");
    $tokdatar = \$doc->{tokdata};
  }

  ##-- get file
  $file = $doc->{tokfile} if (!defined($file));
  $file = "$doc->{outdir}/$doc->{outbase}.t" if (!defined($file));
  $doc->{tokfile} = $file if (!ref($file));

  ##-- get filehandle & print
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  $fh->binmode() if (!ref($file));
  $fh->print( $$tokdatar );
  $fh->close() if (!ref($file));

  $doc->{tokfile_stamp} = timestamp(); ##-- stamp
  return $file;
}

## $file_or_undef = $doc->saveXtokFile($filename_or_fh,\$xtokdata,%opts)
## $file_or_undef = $doc->saveXtokFile($filename_or_fh)
## $file_or_undef = $doc->saveXtokFile()
##  + %opts:
##    format => $level, ##-- formatting level (default=$doc->{format})
##  + $filename_or_fh defaults to $doc->{xtokfile}="$doc->{outdir}/$doc->{outbase}.t.xml"
##  + \$xtokdata defaults to \$doc->{xtokdata}
##  + may implicitly call $doc->tok2xml() (if \$xtokdata and $doc->{xtokdata} are both undefined)
##  + sets $doc->{xtokfile_stamp}
sub saveXtokFile {
  my ($doc,$file,$xtdatar,%opts) = @_;

  ##-- get data
  $xtdatar = \$doc->{xtokdata} if (!$xtdatar);
  if (!$xtdatar || !defined($$xtdatar)) {
    $doc->tok2xml()
      or confess(ref($doc), "::saveXtokFile(): tok2xml() failed for document '$doc->{xmlfile}': $!");
    $xtdatar = \$doc->{xtokdata};
  }

  ##-- get file
  $file = $doc->{xtokfile} if (!defined($file));
  $file = "$doc->{outdir}/$doc->{outbase}.t.xml" if (!defined($file));
  $doc->{xtokfile} = $file if (!ref($file));

  ##-- get filehandle & print
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  $fh->binmode() if (!ref($file));
  my $format = (exists($opts{format}) ? $opts{format} : $doc->{format})||0;
  if (!$format) {
    $fh->print( $$xtdatar );
  } else {
    my $xtdoc = $doc->xTokDoc();
    $xtdoc->toFH($fh, $format);
  }
  $fh->close() if (!ref($file));

  $doc->{xtokfile_stamp} = timestamp(); ##-- stamp
  return $file;
}

## $file_or_undef = $doc->saveSosFile($filename_or_fh,$sosdoc,%opts)
## $file_or_undef = $doc->saveSosFile($filename_or_fh)
## $file_or_undef = $doc->saveSosFile()
##  + %opts:
##    format => $level, ##-- formatting level (default=$doc->{format})
##  + $filename_or_fh defaults to $doc->{sosfile}="$doc->{outdir}/$doc->{outbase}.s.xml"
##  + $sosdoc defaults to $doc->{sosdoc}
##  + may implicitly call $doc->sosxml() (if $sosdoc and $doc->{sosdoc} are both undefined)
##  + sets $doc->{sosfile_stamp}
sub saveSosFile {
  my ($doc,$file,$sosdoc,%opts) = @_;

  ##-- get data
  $sosdoc = $doc->{sosdoc} if (!$sosdoc);
  if (!$sosdoc) {
    $doc->sosxml()
      or confess(ref($doc), "::saveSosFile(): sosxml() failed for document '$doc->{xmlfile}': $!");
    $sosdoc = $doc->{sosdoc};
  }

  ##-- get file
  $file = $doc->{sosfile} if (!defined($file));
  $file = "$doc->{outdir}/$doc->{outbase}.s.xml" if (!defined($file));
  $doc->{sosfile} = $file if (!ref($file));

  ##-- dump
  my $format = (exists($opts{format}) ? $opts{format} : $doc->{format})||0;
  if (ref($file)) {
    $sosdoc->toFH($file, $format);
  } else {
    $sosdoc->toFile($file, $format);
  }

  $doc->{sosfile_stamp} = timestamp(); ##-- stamp
  return $file;
}

## $file_or_undef = $doc->saveSowFile($filename_or_fh,$sowdoc,%opts)
## $file_or_undef = $doc->saveSowFile($filename_or_fh)
## $file_or_undef = $doc->saveSowFile()
##  + %opts:
##    format => $level, ##-- formatting level
##  + $filename_or_fh defaults to $doc->{sowfile}="$doc->{outdir}/$doc->{outbase}.s.xml"
##  + $sowdoc defaults to $doc->{sowdoc}
##  + may implicitly call $doc->sowxml() (if $sowdoc and $doc->{sowdoc} are both undefined)
##  + sets $doc->{sowfile_stamp}
sub saveSowFile {
  my ($doc,$file,$sowdoc,%opts) = @_;

  ##-- get data
  $sowdoc = $doc->{sowdoc} if (!$sowdoc);
  if (!$sowdoc) {
    $doc->sowxml()
      or confess(ref($doc), "::saveSowFile(): sowxml() failed for document '$doc->{xmlfile}': $!");
    $sowdoc = $doc->{sowdoc};
  }

  ##-- get file
  $file = $doc->{sowfile} if (!defined($file));
  $file = "$doc->{outdir}/$doc->{outbase}.s.xml" if (!defined($file));
  $doc->{sowfile} = $file if (!ref($file));

  ##-- dump
  my $format = (exists($opts{format}) ? $opts{format} : $doc->{format})||0;
  if (ref($file)) {
    $sowdoc->toFH($file, $format);
  } else {
    $sowdoc->toFile($file, $format);
  }

  $doc->{sowfile_stamp} = timestamp(); ##-- stamp
  return $file;
}

## $file_or_undef = $doc->saveSoaFile($filename_or_fh,$soadoc,%opts)
## $file_or_undef = $doc->saveSoaFile($filename_or_fh)
## $file_or_undef = $doc->saveSoaFile()
##  + %opts:
##    format => $level, ##-- formatting level
##  + $filename_or_fh defaults to $doc->{soafile}="$doc->{outdir}/$doc->{outbase}.s.xml"
##  + $soadoc defaults to $doc->{soadoc}
##  + may implicitly call $doc->soaxml() (if $soadoc and $doc->{soadoc} are both undefined)
##  + sets $doc->{soafile_stamp}
sub saveSoaFile {
  my ($doc,$file,$soadoc,%opts) = @_;

  ##-- get data
  $soadoc = $doc->{soadoc} if (!$soadoc);
  if (!$soadoc) {
    $doc->soaxml()
      or confess(ref($doc), "::saveSoaFile(): soaxml() failed for document '$doc->{xmlfile}': $!");
    $soadoc = $doc->{soadoc};
  }

  ##-- get file
  $file = $doc->{soafile} if (!defined($file));
  $file = "$doc->{outdir}/$doc->{outbase}.s.xml" if (!defined($file));
  $doc->{soafile} = $file if (!ref($file));

  my $format = (exists($opts{format}) ? $opts{format} : $doc->{format})||0;
  if (ref($file)) {
    $soadoc->toFH($file, $format);
  } else {
    $soadoc->toFile($file, $format);
  }

  $doc->{soafile_stamp} = timestamp(); ##-- stamp
  return $file;
}

## ($sosfile,$sowfile,$soafile) = $doc->saveStandoffFiles(%opts); ##-- array context
## [$sosfile,$sowfile,$soafile] = $doc->saveStandoffFiles(%opts); ##-- scalar context
##  + uses default files
##  + %opts:
##     format => $level,
sub saveStandoffFiles {
  my ($doc,%opts) = @_;
  $doc->saveSosFile(undef,undef,%opts);
  $doc->saveSowFile(undef,undef,%opts);
  $doc->saveSoaFile(undef,undef,%opts);
  my @files = @$doc{qw(sosfile sowfile soafile)};
  return wantarray ? @files : \@files;
}


1; ##-- be happy

__END__