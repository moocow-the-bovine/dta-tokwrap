## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Document.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: document wrapper

package DTA::TokWrap::Document;
use DTA::TokWrap::Base;
use DTA::TokWrap::Version;
use DTA::TokWrap::mkindex;
use DTA::TokWrap::mkbx0;
use DTA::TokWrap::mkbx;

use File::Basename qw(basename dirname);
use IO::File;
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
##    bx0file => $bx0file,  ##-- pre-serialized block-index XML file (default="$outbase.bx0"; optional)
##
##    ##-- mkbx data (see DTA::TokWrap::mkbx)
##    bxdata  => \@bxdata,  ##-- block-list, see DTA::TokWrap::mkbx::mkbx() for details
##    bxfile  => $bxfile,   ##-- serialized block-index CSV file (default="$outbase.bx"; optional)
##    txtfile => $txtfile,  ##-- serialized & hinted text file (default="$outbase.txt"; optional)
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

	  ##-- mkbx data
	  bxdata => undef,
	  bxfile => undef,
	  txtfile => undef,
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

  ##-- return
  return $doc;
}

##==============================================================================
## Methods: annotation & indexing
##==============================================================================

## $doc_or_undef = $doc->mkindex($mkindex)
## $doc_or_undef = $doc->mkindex()
sub mkindex {
  return $_[1]->mkindex($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::mkindex'));
  return DTA::TokWrap::mkindex->mkindex($_[0]);
}

## $doc_or_undef = $doc->mkbx0($mkbx0)
## $doc_or_undef = $doc->mkbx0()
sub mkbx0 {
  return $_[1]->mkbx0($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::mkbx0'));
  return DTA::TokWrap::mkbx0->mkbx0($_[0]);
}

## $doc_or_undef = $doc->mkbx($mkbx)
## $doc_or_undef = $doc->mkbx()
sub mkbx {
  return $_[1]->mkbx($_[0]) if (UNIVERSAL::isa($_[1],'DTA::TokWrap::mkbx'));
  return DTA::TokWrap::mkbx->mkbx($_[0]);
}

##==============================================================================
## Methods: I/O
##==============================================================================

## $bool = $doc->saveBx0File($filename_or_fh,$bx0doc,%opts)
## $bool = $doc->saveBx0File($filename_or_fh)
## $bool = $doc->saveBx0File()
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

  return 1;
}


## $bool = $doc->saveBxFile($filename_or_fh,\@blocks)
## $bool = $doc->saveBxFile($filename_or_fh)
## $bool = $doc->saveBxFile()
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
  return 1;
}

## $bool = $doc->saveTxtFile($filename_or_fh,\@blocks,%opts)
## $bool = $doc->saveTxtFile($filename_or_fh)
## $bool = $doc->saveTxtFile()
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
  return 1;
}


1; ##-- be happy

__END__
