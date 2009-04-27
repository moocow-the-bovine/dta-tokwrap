## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Document.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: document wrapper

package DTA::TokWrap::Document;
use DTA::TokWrap::Base;
use DTA::TokWrap::Version;
use DTA::TokWrap::Utils qw(:libxml :files :time :si);
use DTA::TokWrap::Processor::mkindex;
use DTA::TokWrap::Processor::mkbx0;
use DTA::TokWrap::Processor::mkbx;
use DTA::TokWrap::Processor::tokenize;
use DTA::TokWrap::Processor::tokenize::dummy;
use DTA::TokWrap::Processor::tok2xml;
use DTA::TokWrap::Processor::standoff;

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
#our $TOKENIZE_CLASS = 'DTA::TokWrap::Processor::tokenize';
our $TOKENIZE_CLASS = 'DTA::TokWrap::Processor::tokenize::dummy';

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
##    ##-- Document class
##    class => $class,      ##-- delegate call to $class->new(%args)
##
##    ##-- Source data
##    xmlfile => $xmlfile,  ##-- source filename
##    xmlbase => $xmlbase,  ##-- xml:base for generated files (default=basename($xmlfile))
##
##    ##-- generator data (optional)
##    tw => $tw,              ##-- a DTA::TokWrap object storing individual generators
##    traceOpen  => $leve,    ##-- log-lvel for open() trace (e.g. 'info'; default=undef (none))
##    traceClose => $level,   ##-- log-level for close() trace (e.g. 'trace'; default=undef (none))
##
##    ##-- generated data (common)
##    outdir => $outdir,    ##-- output directory for generated data (default=.)
##    tmpdir => $tmpdir,    ##-- temporary directory for generated data (default=$ENV{DTATW_TMP}||$outdir)
##    keeptmp => $bool,     ##-- if true, temporary document-local files will be kept on $doc->close()
##    outbase => $filebase, ##-- output basename (default=`basename $xmlbase .xml`)
##    format => $level,     ##-- default formatting level for XML output
##
##    ##-- mkindex data (see DTA::TokWrap::Processor::mkindex)
##    cxfile => $cxfile,    ##-- character index file (default="$tmpdir/$outbase.cx")
##    cxdata => $cxdata,    ##-- character index data (see loadCxFile() method)
##    sxfile => $sxfile,    ##-- structure index file (default="$tmpdir/$outbase.sx")
##    txfile => $txfile,    ##-- raw text index file (default="$tmpdir/$outbase.tx")
##
##    ##-- mkbx0 data (see DTA::TokWrap::Processor::mkbx0)
##    bx0doc  => $bx0doc,   ##-- pre-serialized block-index XML::LibXML::Document
##    bx0file => $bx0file,  ##-- pre-serialized block-index XML file (default="$outbase.bx0"; optional)
##
##    ##-- mkbx data (see DTA::TokWrap::Processor::mkbx)
##    bxdata  => \@bxdata,  ##-- block-list, see DTA::TokWrap::mkbx::mkbx() for details
##    bxfile  => $bxfile,   ##-- serialized block-index CSV file (default="$tmpdir/$outbase.bx"; optional)
##    txtfile => $txtfile,  ##-- serialized & hinted text file (default="$tmpdir/$outbase.txt"; optional)
##
##    ##-- tokenize data (see DTA::TokWrap::Processor::tokenize, DTA::TokWrap::Processor::tokenize::dummy)
##    tokdata => $tokdata,  ##-- tokenizer output data (slurped string)
##    tokfile => $tokfile,  ##-- tokenizer output file (default="$tmpdir/$outbase.t"; optional)
##
##    ##-- tokenizer xml data (see DTA::TokWrap::Processor::tok2xml)
##    xtokdata => $xtokdata,  ##-- XML-ified tokenizer output data
##    xtokfile => $xtokfile,  ##-- XML-ified tokenizer output file (default="$outdir/$outbase.t.xml")
##    xtokdoc  => $xtokdoc,   ##-- XML::LibXML::Document for $xtokdata (parsed from string)
##
##    ##-- standoff xml data (see DTA::TokWrap::Processor::standoff)
##    sosdoc  => $sosdata,   ##-- XML::LibXML::Document: sentence standoff data
##    sowdoc  => $sowdata,   ##-- XML::LibXML::Document: token standoff data
##    soadoc  => $soadata,   ##-- XML::LibXML::Document: analysis standoff data
##    ##
##    sosfile => $sosfile,   ##-- filename for $sosdoc (default="$outdir/$outbase.s.xml")
##    sowfile => $sowfile,   ##-- filename for $sowdoc (default="$outdir/$outbase.w.xml")
##    soafile => $soafile,   ##-- filename for $soadoc (default="$outdir/$outbase.a.xml")
##   )
sub new {
  my ($that,%opts) = @_;
  if (defined($opts{class})) {
    my $class = $opts{class};
    delete($opts{class});
    return $class->new(%opts);
  }
  return $that->SUPER::new(%opts);
}

## %defaults = CLASS->defaults()
sub defaults {
  return (
	  ##-- inherited defaults (none)
	  #$_[0]->SUPER::defaults(),

	  ##-- source data
	  xmlfile => undef,
	  xmlbase => undef,

	  ##-- generator data (optional)
	  #tw => undef,
	  #traceOpen => 'trace',
	  #traceClose => 'trace',

	  ##-- generated data (common)
	  outdir => '.',
	  tmpdir => $ENV{DTATW_TMP},
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
  #$doc->{xtokfile}  = $doc->{tmpdir}.'/'.$doc->{outbase}.".t.xml" if (!$doc->{xtokfile});
  $doc->{xtokfile}  = $doc->{outdir}.'/'.$doc->{outbase}.".t.xml" if (!$doc->{xtokfile});

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

## undef = $doc->DESTROY()
##  + destructor; implicit close()
sub DESTROY {
  $_[0]->close(1);
}

##==============================================================================
## Methods: Pseudo-I/O
##==============================================================================

## $newdoc = CLASS_OR_OBJECT->open($xmlfile,%docNewOptions)
##  + wrapper for CLASS_OR_OBJECT->new(), with some additional sanity checks
sub open {
  my ($doc,$xmlfile,@opts) = @_;
  $doc->logconfess("open(): no XML source file specified") if (!defined($xmlfile) || $xmlfile eq '');
  $doc->logconfess("open(): cannot use standard input '-' as a source file") if ($xmlfile eq '-');
  $doc->logconfess("open(): could not open XML source file '$xmlfile': $!") if (!file_try_open($xmlfile));
  $doc = $doc->new(xmlfile=>$xmlfile,open_stamp=>timestamp(),@opts);
  $doc->vlog($doc->{traceOpen},"open($xmlfile)") if ($doc->{traceOpen});
  return $doc;
}

## $bool = $doc->close()
## $bool = $doc->close($is_destructor)
##  + "closes" document $doc
##  + unlinks any temporary files in $doc unless $tw->{keeptmp} is true
##    - all %$doc keys ending in 'file' are considered 'temporary' files, except:
##      xmlfile, xtokfile, sosfile, sowfile, soafile
##  + also, if $is_destructor is false (default), resets all keys in %$doc to
##    default values (making $doc essentially unuseable)
sub close {
  my ($doc,$is_destructor) = @_;
  $doc->vlog($doc->{traceClose},"close($doc->{xmlfile})") if ($doc->{traceClose} && $doc->logInitialized);
  my $rc = 1;
  foreach ($doc->tempfiles()) {
    ##-- unlink temp files
    $rc=0 if (!unlink($_));
  }

  ##-- update {tw} profiling information
  if ($doc->{tw}) {
    my $ntoks = $doc->nTokens() || 0;
    my $nxbytes = $doc->nXmlBytes() || 0;
    my ($keystamp,$key,$stamp,$stamp0,$prof);
    foreach $keystamp (
		       #grep {UNIVERSAL::isa($doc->{tw}{$_},'DTA::TokWrap::Processor')} keys(%{$doc->{tw}})
		       grep {$_ =~ /_stamp$/ && defined($doc->{"${_}0"})} keys(%$doc)
		      )
      {
	($key = $keystamp) =~ s/_stamp$//;
	($stamp0,$stamp) = @$doc{"${key}_stamp0","${key}_stamp"};
	next if (!defined($stamp0) || !defined($stamp));  ##-- ignore processors which haven't run for this doc
	next if ($stamp0 < 0 || $stamp < 0);              ##-- (hack): ignore forced pseudo-stamps
	$prof = $doc->{tw}{profile}{$key} = {} if (!defined($prof=$doc->{tw}{profile}{$key}));
	$prof->{ndocs}++;
	$prof->{ntoks}   += $ntoks;
	$prof->{nxbytes} += $nxbytes;
	$prof->{elapsed} += $stamp - $stamp0;
	$prof->{laststamp} = $stamp;
      }
    $prof = $doc->{tw}{profile}{''} = {} if (!defined($prof = $doc->{tw}{profile}{''}));
    $prof->{ndocs}++;
    $prof->{ntoks}   += $ntoks;
    $prof->{nxbytes} += $nxbytes;
    $prof->{laststamp} = timestamp();
    $prof->{elapsed} += $prof->{laststamp}-$doc->{open_stamp}  if (defined($doc->{open_stamp}));
  }

  ##-- stop here for destructor
  delete($doc->{tw});
  return $rc if ($is_destructor);

  ##-- drop $doc references
  %$doc = (ref($doc)||$doc)->defaults();
  return $rc;
}

## @notempkeys = $doc->notempkeys()
##  + returns hash of document keys ending 'file' which are not considered "temporary"
##  + used by $doc->tempfiles()
sub notempkeys {
  return qw(xmlfile xtokfile sosfile sowfile soafile);
}

## @tempfiles = $doc->tempfiles()
##  + returns list of temporary filenames which have been generated by $doc,
##    or an empty list if $doc->{keeptmp} is true
##  + checks $doc->{"${filekey}_stamp"} to determine whether this document generated
##    the file named by $doc->{"$filekey"}
##  + implementation: returns values of all %$doc keys ending with 'file' except for
##    those returned by $doc->notempkeys()
##  + used by $doc->close()
sub tempfiles {
  my $doc = shift;
  return qw() if (!ref($doc) || $doc->{keeptmp});

  my %notempkeys = map {$_=>undef} $doc->notempkeys();
  return (
	  grep { $_ =~ m/^$doc->{tmpdir}\// }
	  map { $doc->{$_} }
	  grep { $_ =~ /file$/ && defined($doc->{"${_}_stamp"}) && $doc->{"${_}_stamp"} >= 0 && !exists($notempkeys{$_}) }
	  keys(%$doc)
	 );
}

##==============================================================================
## Methods: Low-Level: generator-subclass wrappers
##==============================================================================

## $doc_or_undef = $doc->mkindex($mkindex)
## $doc_or_undef = $doc->mkindex()
##  + see DTA::TokWrap::Processor::mkindex::mkindex()
sub mkindex {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{mkindex}) || 'DTA::TokWrap::Processor::mkindex')->mkindex($_[0]);
}

## $doc_or_undef = $doc->mkbx0($mkbx0)
## $doc_or_undef = $doc->mkbx0()
##  + see DTA::TokWrap::Processor::mkbx0::mkbx0()
sub mkbx0 {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{mkbx0}) || 'DTA::TokWrap::Processor::mkbx0')->mkbx0($_[0]);
}

## $doc_or_undef = $doc->mkbx($mkbx)
## $doc_or_undef = $doc->mkbx()
##  + see DTA::TokWrap::Processor::mkbx::mkbx()
sub mkbx {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{mkbx}) || 'DTA::TokWrap::Processor::mkbx')->mkbx($_[0]);
}

## $doc_or_undef = $doc->tokenize($tokenize)
## $doc_or_undef = $doc->tokenize()
##  + see DTA::TokWrap::Processor::tokenize::tokenize()
##  + default tokenizer class is given by package-global $TOKENIZE_CLASS
sub tokenize {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{tokenize}) || $TOKENIZE_CLASS)->tokenize($_[0]);
}

## $doc_or_undef = $doc->tok2xml($tok2xml)
## $doc_or_undef = $doc->tok2xml()
##  + see DTA::TokWrap::Processor::tok2xml::tok2xml()
sub tok2xml {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{tok2xml}) || 'DTA::TokWrap::Processor::tok2xml')->tok2xml($_[0]);
}

## $doc_or_undef = $doc->sosxml($so)
## $doc_or_undef = $doc->sosxml()
##  + see DTA::TokWrap::Processor::standoff::sosxml()
sub sosxml {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{standoff}) || 'DTA::TokWrap::Processor::standoff')->sosxml($_[0]);
}

## $doc_or_undef = $doc->sowxml($so)
## $doc_or_undef = $doc->sowxml()
##  + see DTA::TokWrap::Processor::standoff::sowxml()
sub sowxml {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{standoff}) || 'DTA::TokWrap::Processor::standoff')->sowxml($_[0]);
}

## $doc_or_undef = $doc->soaxml($so)
## $doc_or_undef = $doc->soaxml()
##  + see DTA::TokWrap::Processor::standoff::soaxml()
sub soaxml {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{standoff}) || 'DTA::TokWrap::Processor::standoff')->soaxml($_[0]);
}

## $doc_or_undef = $doc->standoff($so)
## $doc_or_undef = $doc->standoff()
##  + wrapper for sosxml(), sowxml(), soaxml()
##  + see DTA::TokWrap::Processor::standoff::standoff()
sub standoff {
  return ($_[1] || ($_[0]{tw} && $_[0]{tw}{standoff}) || 'DTA::TokWrap::Processor::standoff')->standoff($_[0]);
}

##==============================================================================
## Methods: Low-Level: data munging and cross-generation
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
      or $doc->logconfess("xtokDoc($doc->{xmlbase}): tok2xml() failed for document '$doc->{xmlfile}': $!");
    $xtdatar = \$doc->{xtokdata};
  }

  ##-- get xml parser
  my $xmlparser = libxml_parser(keep_blanks=>0);
  my $xtdoc = $doc->{xtokdoc} = $xmlparser->parse_string($$xtdatar)
    or $doc->logconfess("xtokDoc($doc->{xmlbase}): could not parse t.xml data as XML: $!");

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
      or $doc->logconfess("loadCxFile($doc->{xmlbase}): mkindex()() failed for document '$doc->{xmlfile}': $!");
    $file = $doc->{cxfile};
  }

  my $cx = $doc->{cxdata} = [];
  my $fh = ref($file) ? $file : IO::File->new("<$file");
  $doc->logconfess("loadCxFile(): open failed for .cx file '$file': $!") if (!$fh);
  $fh->binmode() if (!ref($file));
  while (<$fh>) {
    chomp;
    next if (/^%%/ || /^\s*$/);
    push(@$cx, [split(/\t/,$_)]);
  }
  $fh->close() if (!ref($file));

  $doc->{cxdata_stamp} = file_mtime($file);
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
      or $doc->logconfess("saveBx0File(): mkbx0() failed for document '$doc->{xmlfile}': $!");
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
      or $doc->logconfess("saveBxFile(): mkbx() failed for document '$doc->{xmlfile}': $!");
    $bxdata = $doc->{bxdata};
  }

  ##-- get file
  $file = $doc->{bxfile} if (!defined($file));
  $file = "$doc->{outdir}/$doc->{outbase}.bx" if (!defined($file));
  $doc->{bxfile} = $file if (!ref($file));

  ##-- get filehandle & print
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  $doc->logconfess("saveBxFile(): open failed for output file '$file': $!") if (!$fh);
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
      or $doc->confess("saveTxtFile(): mkbx() failed for document '$doc->{xmlfile}': $!");
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
      or $doc->logconfess("saveTokFile(): tokenize() failed for document '$doc->{xmlfile}': $!");
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
      or $doc->logconfess("saveXtokFile(): tok2xml() failed for document '$doc->{xmlfile}': $!");
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
    my $xtdoc = $doc->xtokDoc();
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
      or $doc->logconfess("saveSosFile(): sosxml() failed for document '$doc->{xmlfile}': $!");
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
      or $doc->logconfess("saveSowFile(): sowxml() failed for document '$doc->{xmlfile}': $!");
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
      or $doc->logconfess("saveSoaFile(): soaxml() failed for document '$doc->{xmlfile}': $!");
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

##==============================================================================
## Methods: Profiling
##==============================================================================

## $ntoks_or_undef = $doc->nTokens()
sub nTokens { return $_[0]{ntoks}; }

## $nxbytes_or_undef = $doc->nXmlBytes()
sub nXmlBytes { return (-s $_[0]{xmlfile}); }

1; ##-- be happy

__END__
