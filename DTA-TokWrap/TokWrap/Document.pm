## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Document.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: document wrapper

package DTA::TokWrap::Document;
use DTA::TokWrap::Base;
use DTA::TokWrap::Version;
use DTA::TokWrap::Utils qw(:libxml);
use DTA::TokWrap::mkindex;
use DTA::TokWrap::mkbx0;
use DTA::TokWrap::mkbx;
use DTA::TokWrap::tokenize;
use DTA::TokWrap::tokenize::dummy;
use DTA::TokWrap::tok2xml;
use DTA::TokWrap::standoff;

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
##    ##-- generated data (common)
##    outdir => $outdir,    ##-- output directory for generated data (default=.)
##    outbase => $filebase, ##-- output basename (default=`basename $xmlbase .xml`)
##
##    ##-- mkindex data (see DTA::TokWrap::mkindex)
##    cxfile => $cxfile,    ##-- character index file (default="$outbase.cx")
##    cxdata => $cxdata,    ##-- character index data (see loadCxFile() method)
##    sxfile => $sxfile,    ##-- structure index file (default="$outbase.sx")
##    txfile => $txfile,    ##-- raw text index file (default="$outbase.tx")
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
	  outbase => undef,

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

  ##-- defaults: mkindex data
  $doc->{cxfile} = $doc->{outdir}.'/'.$doc->{outbase}.".cx" if (!$doc->{cxfile});
  $doc->{sxfile} = $doc->{outdir}.'/'.$doc->{outbase}.".sx" if (!$doc->{sxfile});
  $doc->{txfile} = $doc->{outdir}.'/'.$doc->{outbase}.".tx" if (!$doc->{txfile});

  ##-- defaults: mkbx0 data
  #$doc->{bx0doc} = undef;
  #$doc->{bx0file} = $doc->{outdir}.'/'.$doc->{outbase}.".bx0" if (!$doc->{bx0file});

  ##-- defaults: mkbx data
  #$doc->{bxdata}  = undef;
  #$doc->{bxfile}  = $doc->{outdir}.'/'.$doc->{outbase}.".bx" if (!$doc->{bxfile});
  #$doc->{txtfile} = $doc->{outdir}.'/'.$doc->{outbase}.".txt" if (!$doc->{txtfile});

  ##-- defaults: tokenizer output data
  #$doc->{tokdata}  = undef;
  #$doc->{tokfile}  = $doc->{outdir}.'/'.$doc->{outbase}.".t" if (!$doc->{tokfile});

  ##-- defaults: tokenizer xml data
  #$doc->{xtokdata}  = undef;
  $doc->{xtokfile}  = $doc->{outdir}.'/'.$doc->{outbase}.".t.xml" if (!$doc->{xtokfile});

  ##-- defaults: standoff data
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
## Methods: annotation & indexing
##==============================================================================

## $doc_or_undef = $doc->mkindex($mkindex)
## $doc_or_undef = $doc->mkindex()
##  + see DTA::TokWrap::mkindex::mkindex()
sub mkindex {
  return $_[1]->mkindex($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::mkindex'));
  return DTA::TokWrap::mkindex->mkindex($_[0]);
}

## $doc_or_undef = $doc->mkbx0($mkbx0)
## $doc_or_undef = $doc->mkbx0()
##  + see DTA::TokWrap::mkbx0::mkbx0()
sub mkbx0 {
  return $_[1]->mkbx0($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::mkbx0'));
  return DTA::TokWrap::mkbx0->mkbx0($_[0]);
}

## $doc_or_undef = $doc->mkbx($mkbx)
## $doc_or_undef = $doc->mkbx()
##  + see DTA::TokWrap::mkbx::mkbx()
sub mkbx {
  return $_[1]->mkbx($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::mkbx'));
  return DTA::TokWrap::mkbx->mkbx($_[0]);
}

## $doc_or_undef = $doc->tokenize($tokenize)
## $doc_or_undef = $doc->tokenize()
##  + see DTA::TokWrap::tokenize::tokenize()
##  + default tokenizer class is given by package-global $TOKENIZE_CLASS
sub tokenize {
  return $_[1]->tokenize($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::tokenize'));
  return $TOKENIZE_CLASS->tokenize($_[0]);
}

## $doc_or_undef = $doc->tok2xml($tok2xml)
## $doc_or_undef = $doc->tok2xml()
##  + see DTA::TokWrap::tok2xml::tok2xml()
sub tok2xml {
  return $_[1]->tok2xml($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::tok2xml'));
  return DTA::TokWrap::tok2xml->tok2xml($_[0]);
}

## $doc_or_undef = $doc->sosxml($so)
## $doc_or_undef = $doc->sosxml()
##  + see DTA::TokWrap::standoff::sosxml()
sub sosxml {
  return $_[1]->sosxml($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::standoff'));
  return DTA::TokWrap::standoff->sosxml($_[0]);
}

## $doc_or_undef = $doc->sowxml($so)
## $doc_or_undef = $doc->sowxml()
##  + see DTA::TokWrap::standoff::sowxml()
sub sowxml {
  return $_[1]->sowxml($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::standoff'));
  return DTA::TokWrap::standoff->sowxml($_[0]);
}

## $doc_or_undef = $doc->soaxml($so)
## $doc_or_undef = $doc->soaxml()
##  + see DTA::TokWrap::standoff::soaxml()
sub soaxml {
  return $_[1]->soaxml($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::standoff'));
  return DTA::TokWrap::standoff->soaxml($_[0]);
}

## $doc_or_undef = $doc->standoff($so)
## $doc_or_undef = $doc->standoff()
##  + wrapper for sosxml(), sowxml(), soaxml()
##  + see DTA::TokWrap::standoff::standoff()
sub standoff {
  return $_[1]->standoff($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::standoff'));
  return DTA::TokWrap::standoff->standoff($_[0]);
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

  return $cx;
}

##----------------------------------------------------------------------
## Methods: I/O: output

## $file_or_undef = $doc->saveBx0File($filename_or_fh,$bx0doc,%opts)
## $file_or_undef = $doc->saveBx0File($filename_or_fh)
## $file_or_undef = $doc->saveBx0File()
##  + %opts:
##     format => $level,  ##-- do output formatting?
##  + $bx0doc defaults to $doc->{bx0doc}
##  + $filename_or_fh defaults to $doc->{bx0file}="$doc->{outdir}/$doc->{outbase}.bx0"
##  + sets $doc->{bx0file} if a filename is passed or defaulted
##  + may implicitly call $doc->mkbx0() (if $bx0doc and $doc->{bxdata} are both false)
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
  if (ref($file)) {
    $bx0doc->toFh($opts{format}||0);
  } else {
    $bx0doc->toFile($opts{format}||0);
  }

  return $file;
}

## $file_or_undef = $doc->saveBxFile($filename_or_fh,\@blocks)
## $file_or_undef = $doc->saveBxFile($filename_or_fh)
## $file_or_undef = $doc->saveBxFile()
##  + \@blocks defaults to $doc->{bxdata}
##  + $filename_or_fh defaults to $doc->{bxfile}="$doc->{outdir}/$doc->{outbase}.bx"
##  + may implicitly call $doc->mkbx() (if \@blocks and $doc->{bxdata} are both false)
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
  return $file;
}

## $file_or_undef = $doc->saveTokFile($filename_or_fh,\$tokdata)
## $file_or_undef = $doc->saveTokFile($filename_or_fh)
## $file_or_undef = $doc->saveTokFile()
##  + $filename_or_fh defaults to $doc->{tokfile}="$doc->{outdir}/$doc->{outbase}.t"
##  + \$tokdata defaults to \$doc->{tokdata}
##  + may implicitly call $doc->tokenize() (if \$tokdata and $doc->{tokdata} are both undefined)
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
  return $file;
}

## $file_or_undef = $doc->saveXtokFile($filename_or_fh,\$xtokdata,%opts)
## $file_or_undef = $doc->saveXtokFile($filename_or_fh)
## $file_or_undef = $doc->saveXtokFile()
##  + %opts:
##    format => $level, ##-- formatting level
##  + $filename_or_fh defaults to $doc->{xtokfile}="$doc->{outdir}/$doc->{outbase}.t.xml"
##  + \$xtokdata defaults to \$doc->{xtokdata}
##  + may implicitly call $doc->tok2xml() (if \$xtokdata and $doc->{xtokdata} are both undefined)
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
  if (!$opts{format}) {
    $fh->print( $$xtdatar );
  } else {
    my $xtdoc = $doc->xTokDoc();
    $xtdoc->toFH($fh, $opts{format});
  }
  $fh->close() if (!ref($file));
  return $file;
}

## $file_or_undef = $doc->saveSosFile($filename_or_fh,$sosdoc,%opts)
## $file_or_undef = $doc->saveSosFile($filename_or_fh)
## $file_or_undef = $doc->saveSosFile()
##  + %opts:
##    format => $level, ##-- formatting level
##  + $filename_or_fh defaults to $doc->{sosfile}="$doc->{outdir}/$doc->{outbase}.s.xml"
##  + $sosdoc defaults to $doc->{sosdoc}
##  + may implicitly call $doc->sosxml() (if $sosdoc and $doc->{sosdoc} are both undefined)
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
  if (ref($file)) {
    $sosdoc->toFH($file, $opts{format}||0);
  } else {
    $sosdoc->toFile($file, $opts{format}||0);
  }

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
  if (ref($file)) {
    $sowdoc->toFH($file, $opts{format}||0);
  } else {
    $sowdoc->toFile($file, $opts{format}||0);
  }

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

  ##-- dump
  if (ref($file)) {
    $soadoc->toFH($file, $opts{format}||0);
  } else {
    $soadoc->toFile($file, $opts{format}||0);
  }

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
