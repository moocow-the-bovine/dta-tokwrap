## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor::mkbx.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: (bx0doc,tx) -> bxdata

package DTA::TokWrap::Processor::mkbx;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :libxml :libxslt :slurp :time);
use DTA::TokWrap::Processor;

use XML::Parser;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor);

##==============================================================================
## Constructors etc.
##==============================================================================

## $mbx = CLASS_OR_OBJ->new(%args)
## %defaults = CLASS->defaults()
##  + %args, %defaults, %$mbx:
##    (
##     ##-- Block-sorting: hints
##     wbStr => $wbStr,                       ##-- word-break hint text
##     sbStr => $sbStr,                       ##-- sentence-break hint text
##     sortkey_attr => $attr,                 ##-- sort-key attribute (default='dta.tw.key'; should jive with mkbx0)
##     ##
##     ##-- Block-sorting: low-level data
##     xp    => $xml_parser,                  ##-- XML::Parser object for parsing $doc->{bx0doc}
##   )
sub defaults {
  my $that = shift;
  return (
	  ##-- inherited
	  $that->SUPER::defaults(),

	  ##-- Block-sorting: hints
	  wbStr => "\n\$WB\$\n",
	  sbStr => "\n\$SB\$\n",
	  sortkey_attr => 'dta.tw.key',

	  ##-- Block-sorting: parser
	  xp => undef,
	 );
}

## $mbx = $mbx->init()
sub init {
  my $mbx = shift;

  ##-- create & initialize XML parser
  $mbx->initXmlParser() if (!defined($mbx->{xp}));

  return $mbx;
}

## $xp = $mbx->initXmlParser()
##  + create & initialize $mbx->{xp}, an XML::Parser object
sub initXmlParser {
  my $mbx = shift;

  ##--------------------------------------------
  ## XML::Parser Handlers: closure variables
  my ($blk);         ##-- $blk: global: currently running block
  my ($key);         ##-- $key: global: currently active sort key
  my $blocks = [];   ##-- \@blocks : all parsed blocks
  my $keystack = []; ##-- \@keystack : stack of (inherited) sort keys
  my $key2i = {};    ##-- \%key2i : maps keys to the block-index of their first occurrence, for block-sorting
  my ($keyAttr);     ##-- $keyAttr : attribute name for sort keys

  ##-- @target_elts : block-like elements
  my @target_elts = qw(c s w);
  my %target_elts = map {$_=>undef} @target_elts;

  my ($xp,$eltname,%attrs);
  my ($xoff,$toff); ##-- $xoff,$toff: global: current XML-, tx-byte offset
  my ($xlen,$tlen); ##-- $xlen,$tlen: global: current XML-, tx-byte length

  ##-- save closure data (for debugging)
  @$mbx{qw(blocks keystack key2i)} = ($blocks, $keystack, $key2i);
  @$mbx{qw(blkr keyr)}   = (\$blk, \$key);
  @$mbx{qw(xoffr xlenr)} = (\$xoff,\$xlen);
  @$mbx{qw(toffr tlenr)} = (\$toff,\$tlen);

  ##--------------------------------------------
  ## XML::Parser Handlers: closures

  ##--------------------------------------
  ## undef = cb_init($expat)
  my $cb_init = sub {
    #my ($xp) = shift;

    $keyAttr   = $mbx->{sortkey_attr};
    $blk       = {key=>'__ROOT__',elt=>'__ROOT__',xoff=>0,xlen=>0, toff=>0,tlen=>0};
    $key       = $blk->{key};
    $blocks    = [ $blk ];
    $keystack  = [ $key ];
    $key2i     = { $key => 0 };

    ##-- offsets & lengths
    ($xoff,$xlen) = (0,0);
    ($toff,$tlen) = (0,0);

    ##-- save closure data (for debugging)
    @$mbx{qw(blocks keystack key2i)} = ($blocks, $keystack, $key2i);
    @$mbx{qw(blkr keyr)}   = (\$blk, \$key);
    @$mbx{qw(xoffr xlenr)} = (\$xoff,\$xlen);
    @$mbx{qw(toffr tlenr)} = (\$toff,\$tlen);
  };

  ##--------------------------------------
  ## undef = cb_start($expat, $elt,%attrs)
  my $cb_start = sub {
    ($xp,$eltname,%attrs) = @_;

    ##-- check for sort key
    if (exists($attrs{$keyAttr})) {
      $key = $attrs{$keyAttr};
      $key2i->{$key} = scalar(@$blocks);
    }

    ##-- update key stack
    push(@$keystack,$key);

    ##-- check for target elements
    if (exists($target_elts{$eltname})) {
      ($xlen,$tlen) = (0,0); ##-- hack for hints
      ($xoff,$xlen, $toff,$tlen) = split(/ /,$attrs{n}) if (exists($attrs{n}));
      push(@$blocks, $blk={ key=>$key, elt=>$eltname, xoff=>$xoff,xlen=>$xlen, toff=>$toff,tlen=>$tlen });
    }
  };

  ##--------------------------------------
  ## undef = cb_end($expat, $elt)
  my $cb_end  = sub {
    pop(@$keystack);
    $key = $keystack->[$#$keystack];
  };

  ##--------------------------------------------
  ## XML::Parser object
  $mbx->{xp} = XML::Parser->new(
			       ErrorContext => 1,
			       ProtocolEncoding => 'UTF-8',
			       #ParseParamEnt => '???',
			       Handlers => {
					    Init  => $cb_init,
					    Start => $cb_start,
					    End   => $cb_end,
					    #Char  => $cb_char,
					    #Final => $cb_final,
					   },
			      );

  return $mbx;
}

##==============================================================================
## Methods: mkbx (bx0doc, txfile) => bxdata
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->mkbx($doc)
## + $doc is a DTA::TokWrap::Document object
## + $doc->{bx0doc} should already be populated (else $doc->mkbx0() will be called)
## + %$doc keys:
##    bx0doc  => $bx0doc,  ##-- (input) preliminary block-index data (XML::LibXML::Document)
##    txfile  => $txfile,  ##-- (input) raw text index filename
##    bxdata  => \@blocks, ##-- (output) serialized block index
##    mkbx_stamp0 => $f,   ##-- (output) timestamp of operation begin
##    mkbx_stamp  => $f,   ##-- (output) timestamp of operation end
##    bxdata_stamp => $f,  ##-- (output) timestamp of operation end
## + block data: @blocks = ($blk0, ..., $blkN); %$blk =
##   (
##    key    =>$sortkey, ##-- (inherited) sort key
##    elt    =>$eltname, ##-- element name which created this block
##    xoff   =>$xoff,    ##-- XML byte offset where this block run begins
##    xlen   =>$xlen,    ##-- XML byte length of this block (0 for hints)
##    toff   =>$toff,    ##-- raw-text byte offset where this block run begins
##    tlen   =>$tlen,    ##-- raw-text byte length of this block (0 for hints)
##    otext  =>$otext,   ##-- output text for this block
##    otoff  =>$otoff,   ##-- output text byte offset where this block run begins
##    otlen  =>$otlen,   ##-- output text length (bytes)
##   )
sub mkbx {
  my ($mbx,$doc) = @_;

  ##-- log, stamp
  $mbx->vlog($mbx->{traceLevel},"mkbx($doc->{xmlfile})");
  $doc->{mkbx_stamp0} = timestamp();

  ##-- sanity check(s)
  $mbx = $mbx->new() if (!ref($mbx));
  #$doc->mkbx0() if (!$doc->{bx0doc});
  $mbx->logconfess("mkbx($doc->{xmlbase}): no bx0doc key defined")
    if (!$doc->{bx0doc});
  $mbx->logconfess("mkbx($doc->{xmlbase}): no .tx file defined")
    if (!$doc->{txfile});
  #$doc->mkindex() if (!-r $doc->{txfile});
  confess(ref($mbx), "::mkbx0($doc->{xmlfile}): .tx file '$doc->{txfile}' not readable")
    if (!-r $doc->{txfile});

  ##-- parse bx0doc
  my $bx0str = $doc->{bx0doc}->toString(0);
  $mbx->{xp}->parse($bx0str);

  ##-- prune empty blocks & sort
  my $blocks = $mbx->{blocks};
  $mbx->prune_empty_blocks($blocks);
  $mbx->sort_blocks($blocks);

  ##-- slurp text file
  my $txbuf = '';
  slurp_file($doc->{txfile},\$txbuf);
  $mbx->{txbufr} = \$txbuf; ##-- DEBUG

  ##-- populate block output-text keys
  $mbx->compute_block_text($blocks, \$txbuf);

  ##-- update document
  $doc->{bxdata} = $blocks;
  $doc->{mkbx_stamp} = $doc->{bxdata_stamp} = timestamp(); ##-- stamp
  return $doc;
}

## \@blocks = $mbx->prune_empty_blocks(\@blocks)
## \@blocks = $mbx->prune_empty_blocks()
## + removes empty 'c'-type blocks
## + \@blocks defaults to $mbx->{blocks}
sub prune_empty_blocks {
  my ($mbx,$blocks) = @_;
  $blocks  = $mbx->{blocks} if (!$blocks);
  @$blocks = grep { $_->{elt} ne 'c' || $_->{tlen} > 0 } @$blocks;
  return $blocks;
}

## \@blocks = $mbx->sort_blocks(\@blocks)
##  + sorts \@blocks using $mb->{key2i}
## + \@blocks defaults to $mbx->{blocks}
sub sort_blocks {
  my ($mbx,$blocks) = @_;
  my $key2i = $mbx->{key2i};
  $blocks = $mbx->{blocks} if (!$blocks);
  @$blocks = (
	      sort {
		($key2i->{$a->{key}} <=> $key2i->{$b->{key}}
		 || $a->{key}  cmp $b->{key}
		 || $a->{xoff} <=> $b->{xoff})
	      } @$blocks
	     );
  return $blocks;
}


## \@blocks = $mbx->compute_block_text(\@blocks, \$txbuf)
## \@blocks = $mbx->compute_block_text(\@blocks)
## \@blocks = $mbx->compute_block_text()
##  + sets $blk->{otoff}, $blk->{otlen}, $blk->{otext} for each block $blk
##  + \$txbuf defaults to $mbx->{txbufr}
##  + \@blocks defaults to $mbx->{blocks}
##  + \@blocks should already have been sorted
sub compute_block_text {
  my ($mbx,$blocks,$txbufr) = @_;
  $blocks = $mbx->{blocks} if (!$blocks);
  $txbufr = $mbx->{txbufr} if (!$txbufr);
  my $otoff = 0;
  my ($SB,$WB) = @$mbx{qw(sbStr wbStr)};
  my ($blk);
  foreach $blk (@$blocks) {
    ##-- specials
    if    ($blk->{elt} eq 'w') { $blk->{otext}=$WB; }
    elsif ($blk->{elt} eq 's') { $blk->{otext}=$SB; }
    else {
      $blk->{otext} = substr($$txbufr, $blk->{toff}, $blk->{tlen});
    }
    $blk->{otoff} = $otoff;
    $blk->{otlen} = length($blk->{otext});
    $otoff += $blk->{otlen};
  }
  return $blocks;
}

##==============================================================================
## Methods: I/O
##==============================================================================


1; ##-- be happy

