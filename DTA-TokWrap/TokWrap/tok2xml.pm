## -*- Mode: CPerl -*-

## File: DTA::TokWrap::tok2xml.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: t -> t.xml

package DTA::TokWrap::tok2xml;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :libxml :libxslt :slurp :time);

use IO::File;
use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Base);

#our ($CX_ID,$CX_XOFF,$CX_XLEN,$CX_TOFF,$CX_TLEN,$CX_TEXT);
#BEGIN {
#  DTA::TokWrap::Document->import(':cx');
#}

## $NOC
##  + integer indicating a missing or implicit 'c' record
our $NOC = unpack('N',pack('N',-1));

##==============================================================================
## Constructors etc.
##==============================================================================

## $t2x = CLASS_OR_OBJ->new(%args)
## %defaults = CLASS->defaults()
##  + %args, %defaults, %$t2x:
##    (
##     ##-- output document structure
##     docElt   => $elt,  ##-- output document element
##     sElt     => $elt,  ##-- output sentence element
##     wElt     => $elt,  ##-- output token element
##     aElt     => $elt,  ##-- output token-analysis element
##     posAttr  => $attr, ##-- output byte-position attribute
##     textAttr => $attr, ##-- output token-text attribute
##     )
sub defaults {
  my $that = shift;
  return (
	  ##-- inherited
	  $that->SUPER::defaults(),

	  ##-- output structure
	  docElt => 'sentences',
	  sElt   => 's',
	  wElt   => 'w',
	  aElt   => 'a',
	  posAttr => 'b',
	  textAttr => 't',
	 );
}

## $t2x = $t2x->init()

##==============================================================================
## Methods: tok2xml (bx0doc, txfile) => bxdata
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->tok2xml($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    bxdata  => \@bxdata,   ##-- (input) block index data; else $doc->mkbx() is called
##    tokdata => $tokdata,   ##-- (input) tokenizer output data (string)
##    cxdata  => \@cxchrs,   ##-- (input) character index data (array of arrays); else $doc->loadCxFile() is called
##    cxfile  => $cxfile,    ##-- (input) character index file
##    xtokdata => $xtokdata, ##-- (output) tokenizer output as XML
##    nchrs   => $nchrs,     ##-- (output) number of character index records
##    ntoks   => $ntoks,     ##-- (output) number of tokens parsed
##    tok2xml_stamp0 => $f,  ##-- (output) timestamp of operation begin
##    tok2xml_stamp  => $f,  ##-- (output) timestamp of operation end
##    xtokdata_stamp => $f,  ##-- (output) timestamp of operation end
## + $%t2x keys (temporary, for debugging):
##    tb2ci   => $tb2ci,    ##-- (temp) s.t. vec($tb2ci, $txbyte, 32) = $char_index_of_txbyte
##    ntb     => $ntb,      ##-- (temp) number of text bytes
## + may implicitly call $doc->mkbx(), $doc->loadCxFile(), $doc->tokenize()
sub tok2xml {
  my ($t2x,$doc) = @_;

  ##-- sanity check(s)
  $t2x = $t2x->new() if (!ref($t2x));
  $doc->mkbx() if (!$doc->{bxdata});
  $doc->loadCxFile() if (!$doc->{cxdata});
  confess(ref($t2x), "::tok2xml($doc->{xmlfile}): failed to load .cx data") if (!$doc->{cxdata});
  $doc->tokenize() if (!defined($doc->{tokdata}));
  confess(ref($t2x), "::tok2xml($doc->{xmlfile}): no tokenizer output data") if (!defined($doc->{tokdata}));

  $doc->{tok2xml_stamp0} = timestamp(); ##-- stamp

  ##-- create $tb2ci, $ob2ci index vectors
  $t2x->txbyte_to_ci($doc->{cxdata});
  $t2x->txtbyte_to_ci($doc->{cxdata}, $doc->{bxdata});

  ##-- process tokenizer data
  $t2x->process_tt_data($doc);

  ##-- update properties
  $doc->{nchrs} = $t2x->{nchrs} = scalar(@{$doc->{cxdata}});
  $doc->{tok2xml_stamp} = $doc->{xtokdata_stamp} = timestamp(); ##-- stamp

  ##-- cleanup temporary data
  #delete(@$t2x{qw(tb2ci ob2ci ntb nchr)});

  ##-- return
  return $doc;
}

## \$tb2ci = $t2x->txbyte_to_ci(\@cxdata)
##  + sets %$t2x keys: tb2ci, ntb, nchr
sub txbyte_to_ci {
  my ($t2x,$cx) = @_;

  ##-- index variables
  my $CX_TOFF = $DTA::TokWrap::Document::CX_TOFF;
  my $CX_TLEN = $DTA::TokWrap::Document::CX_TLEN;

  my ($ci,$toff,$tlen);
  $t2x->{tb2ci} = '';
  my $tb2cir = \$t2x->{tb2ci};
  vec($$tb2cir, $cx->[$#$cx][$CX_TOFF]+$cx->[$#$cx][$CX_TLEN], 32) = $#$cx; ##-- initialize  / allocate
  foreach $ci (0..$#$cx) {
    ($toff,$tlen) = @{$cx->[$ci]}[$CX_TOFF,$CX_TLEN];
    substr($$tb2cir, $toff*4, $tlen*4) = pack('N',$ci) x $tlen;
  }

  ##-- properties
  $t2x->{ntb} = length($$tb2cir)/4;
  $t2x->{nchrs} = scalar(@$cx);

  return $tb2cir;
}

## \$ob2ci = $t2x->txtbyte_to_ci(\@cxdata,\@bxdata,\$tb2ci)
##   + sets %$t2x keys: ob2ci
sub txtbyte_to_ci {
  my ($t2x,$cx,$bx,$tb2cir) = @_;
  $tb2cir = \$t2x->{tb2ci} if (!$tb2cir);
  $t2x->{ob2ci} = '';
  my $ob2cir = \$t2x->{ob2ci};
  my ($blk);
  my ($id,$toff,$tlen,$otoff,$otlen);
  my ($obi,$ci);
  foreach $blk (@$bx) {
    ($toff,$tlen,$otoff,$otlen) = @$blk{qw(toff tlen otoff otlen)};
    if ($tlen > 0) {
      ##-- normal text
      foreach $obi (0..($otlen-1)) {
	$ci = vec($$ob2cir, $otoff+$obi, 32) = vec($$tb2cir, $toff+$obi, 32);
	if ($cx->[$ci][0] =~ /^\$.*\$$/) {
	  ##-- special character (e.g. <lb/>): map to $NOC
	  vec($$ob2cir, $otoff+$obi, 32) = $NOC;
	}
      }
    } else {
      ##-- hint, implicit break, or other special
      foreach $obi (0..($otlen-1)) {
	vec($$ob2cir, $otoff+$obi, 32) = $NOC;
      }
    }
  }

  return $ob2cir;
}

## \$tokxmlr = $t2x->process_tt_data($doc)
##  + uses $doc->{cxdata}, $doc->{xmlbase}, $t2x->{ob2ci}, ...
##  + sets $doc->{xtokdata}, $doc->{ntoks}
sub process_tt_data {
  my ($t2x,$doc) = @_;

  ##-- object variables
  my $cxdata = $doc->{cxdata};
  my $ob2cir = \$t2x->{ob2ci};
  $doc->{xtokdata} = '';
  my $outr = \$doc->{xtokdata};
  my $tokdatar  = \$doc->{tokdata};
  my ($docElt,$sElt,$wElt,$aElt,$posAttr,$textAttr) = @$t2x{qw(docElt sElt wElt aElt posAttr textAttr)};

  ##-- process variables
  my ($line,$text,$otofflen,$otoff,$otlen,@rest);
  my ($wi,$si,$s_open) = (0,0,0);
  my ($wid);
  my ($last_cid, @w_cids);
  my $ntoks = 0;

  my $CX_ID = $DTA::TokWrap::Document::CX_ID;

  ##-- header
  $$outr = ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	    ."<$docElt xml:base=\"$doc->{xmlbase}\">"
	   );

  while ($$tokdatar =~ /^(.*)$/mg) {
    $line = $1;
    next if ($line =~ m/^\s*%%/);

    ##-- check for EOS
    if ($line eq '') {
      $$outr .= "</$sElt>" if ($s_open);
      $s_open = 0;
      next;
    }

    ##-- normal token: parse it
    ($text,$otofflen,@rest) = split(/\t/,$line);
    ($otoff,$otlen) = split(/\s+/,$otofflen);
    $last_cid = undef;
    @w_cids = (
	       map {$_->[$CX_ID]}
	       @$cxdata[
			grep { $_ != $NOC && (!defined($last_cid) || $_ != $last_cid) && (($last_cid=$_)||1) }
			##--
			#map {vec($ob2ci, $_, $VLEN_CI)}
			#($otoff..($otoff+$otlen-1))
			##--
			unpack("N$otlen", substr($$ob2cir, $otoff*4, $otlen*4))
		       ],
	      );

    ##-- make text output XML-save
    foreach ($text,@rest) {
      s/\&/&amp;/g;
      s/\"/&quot;/g;
      s/\'/&apos;/g;
      s/\</&lt;/g;
      s/\>/&gt;/g;
      s/\t/&#09;/g;
      s/\n/&#10;/g;
      s/\r/&#13;/g;
    }

    ##-- ... and create XML output
    $wid = "w".($wi++);
    $$outr .= (''
	       ##-- maybe open new sentence: <s>
	       .(!$s_open ? ("<$sElt xml:id=\"s".(++$si)."\">") : '')
	       ##
	       ##-- common token properties: s/w
	       .("<$wElt xml:id=\"$wid\" $posAttr=\"$otoff $otlen\" $textAttr=\"$text\" c=\"".join(' ', @w_cids)."\"")
	       ##
	       ##-- additional analyses: s/w/a
	       .(@rest
		 ? (">".join('',(map { "<$aElt>$_</$aElt>" } @rest))."</$wElt>")
		 : "/>"),
	      );
    $s_open = 1;

    ##-- profiling
    ++$ntoks;
  }

  $$outr .= (
	     ##-- flush any open sentence
	     ($s_open ? "</$sElt>" : '')
	     ##
	     ##-- close document
	     ."</$docElt>"
	     ."\n" ##-- always terminate file with a newline
	    );

  $doc->{ntoks} = $ntoks;
  return $outr;
}


1; ##-- be happy

