## -*- Mode: CPerl; coding: utf-8; -*-

## File: DTA::TokWrap::Processor::tok2xml.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: t -> t.xml, via dtatw-tok2xml

package DTA::TokWrap::Processor::addws;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :files :slurp :time);
use DTA::TokWrap::Processor;

use IO::File;
use XML::Parser;
use Carp;
use strict;

#use utf8;
use bytes;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor);

##-- constants for accessing $wseg,$sseg structures
our $SEG_XREF = 0;
our $SEG_XOFF = 1;
our $SEG_XLEN = 2;
our $SEG_SEGI = 3;
our $SEG_SID   = 4;
our $SEG_SBEGI = 5;
our $SEG_SPRVI = 6;
our $SEG_SNXTI = 7;
our $SEG_SEND  = 8;

##==============================================================================
## Constructors etc.
##==============================================================================

## $t2x = CLASS_OR_OBJ->new(%args)
## %defaults = CLASS->defaults()
##  + static class-dependent defaults
##  + %args, %defaults, %$t2x:
##    (
##     ##-- configuration options
##     wIdAttr => $attr,	##-- attribute in which to place literal id for <w>-fragments
##     sIdAttr => $attr,	##-- attribute in which to place literal id for <s>-fragments
##     addwsInfo => $level, 	##-- log-level for summary (default='debug')
##
##     ##-- low-level data
##     xprs => $xprs,		##-- low-level XML::Parser object
##     w_segs => \@w_segs,	##-- @w_segs = ( $w1seg1, ..., $wIseg1, ..., $wIseg2, ..., $wNsegN )
##				##     + where:
##				##       $wXsegX = [$xref,$xoff,$xlen,$segi, $sid,$sbegi,$sprvi,$snxti,$send]
##				##         $xref = $str, ##-- xml:id of the <w> to which this segment belongs
##				##         $xoff = $int, ##-- byte offset in $srcbuf of this <w>-segment's contents
##				##         $xlen = $int, ##-- byte length in $srcbuf of this <w>-segment's contents
##				##         $segi = $int, ##-- original segment index (+1): 1 <= $segi <= $wid2nsegs{$xref}
##				##         $sid  = $str, ##-- xml:id of the <s> element to which this <w> belongs
##				##         $sbegi = $int, ##-- <s>-segment index (+1) to be opened before this token: 1 <= $ssegi <= $wid2nsegs{$xref} [see find_s_segments()]
##				##         $sprvi = $int,  ##-- previous <s>-segment index (+1)
##				##         $snxti = $int,  ##-- next <s>-segment index (+1)
##				##         $send  = $bool, ##-- true iff the enclosing <s>-segment should be closed after this <w>-segment
##				##     + @w_segs is sorted in logical (serialized) order
##    wid2nsegs => \%wid2nsegs, ##
##    sid2nsegs => \%sid2nsegs, ##
##    )
sub defaults {
  my $that = shift;
  return (
	  ##-- inherited
	  $that->SUPER::defaults(),

	  ##-- user attributes
	  sIdAttr => 'id',
	  wIdAttr => 'id',
	  addwsInfo => 'debug',

	  ##-- low-level
	 );
}

## $po = $po->init()
##  compute dynamic object-dependent defaults
sub init {
  my $po = shift;

  return $po;
}

##==============================================================================
## Methods: Utils
##==============================================================================

##----------------------------------------------------------------------
## $po = $po->xmlParser()
##   + returns cached $po->{xprs} if available, otherwise creates new one
sub xmlParser {
  my $po = shift;
  return $po->{xprs} if (ref($po) && defined($po->{xprs}));

  ##-- labels
  my $prog = ref($po).": ".Log::Log4perl::MDC->get('xmlbase');

  ##--------------------------------------------------------------
  ## XML::Parser handlers (for standoff .t.xml file WITH //w/@xb attribute)
  my ($_xp, $_elt, %_attrs);
  my ($wid,$sid);  ##-- id of currently open <w> (rsp. <s>), or undef
  my ($nw);	   ##-- number of tokens (//w elements) parsed
  my ($ns);	   ##-- number of sentences (//s elements) parsed
  my ($w_segs,$wid2nsegs,$sid2nsegs) = @$po{qw(w_segs wid2nsegs sid2nsegs)} = ([],{},{});

  ##----------------------------
  ## undef = cb_init($expat)
  my $cb_init = sub {
    $wid        = undef;
    $nw         = 0;
    $ns         = 0;
    @$w_segs    = qw();
    %$wid2nsegs = qw();
    %$sid2nsegs = qw();
  };

  ##----------------------------
  ## undef = cb_start($expat, $elt,%attrs)
  my ($xb,$xbi,@xbs);
  my $cb_start = sub {
    #($_xp,$_elt,%_attrs) = @_;
    %_attrs = @_[2..$#_];
    if ($_[1] eq 'w') {
      $wid = $_attrs{'id'} || $_attrs{'xml:id'};
      ++$nw;
      if (defined($xb=$_attrs{'xb'})) {
	##-- v0.34-1 .t.xml format: xml-bytes in //w/@xb
	$xbi = 0;
	foreach (split(/\s+/,$xb)) {
	  if (/^([0-9]+)\+([0-9]+)/) {
	    push(@$w_segs,[$wid,$1,$2,++$xbi, $sid,undef,undef,undef,undef]);
	  } else {
	    $_[0]->xpcroak("$prog: could not parse //w/\@xb attribute");
	  }
	}
	$wid2nsegs->{$wid} = $xbi;
      }
      else {
	$_[0]->xpcroak("$prog: no //w/\@xb attribute defined (do you have DTA::TokWrap >= v0.34-1?)");
      }
    }
    elsif ($_[1] eq 's') {
      $sid = $_attrs{'id'} || $_attrs{'xml:id'};
      ++$ns;
    }
  };

  ##----------------------------
  ## undef = cb_end($expat,$elt)
  my $cb_end = sub {
    if    ($_[1] eq 'w') { $wid=undef; }
    elsif ($_[1] eq 's') { $sid=undef; }
  };

  ##----------------------------
  ## undef = cb_final($expat)
  my $cb_final = sub {
    #@w_segs = sort {$a->[$SEG_XOFF] <=> $b->[$SEG_XOFF]} @w_segs; ##-- NOT HERE
    @$po{qw(ns nw w_segs wid2nsegs sid2nsegs)} = ($ns,$nw,$w_segs,$wid2nsegs,$sid2nsegs);
  };

  ##----------------------------
  ##-- initialize XML::Parser (for .t.xml file)
  $po->{xprs} = XML::Parser->new(
				 ErrorContext => 1,
				 ProtocolEncoding => 'UTF-8',
				 #ParseParamEnt => '???',
				 Handlers => {
					      Init  => $cb_init,
					      Start => $cb_start,
					      End   => $cb_end,
					      Final => $cb_final,
					     },
			   )
    or $po->logconfess("couldn't create XML::Parser for standoff file");

  return $po->{xprs};
}

##----------------------------------------------------------------------
## Subs: compute //s segment attributes in @{$po->{w_segs}}

## undef = $po->find_s_segments()
##  + populates @$seg[$SEG_SXLEN,$SEG_SSEGI] for segments in @w_segs=@{$po->{w_segs}}
##  + assumes @w_segs is sorted on serialized (text) document order
sub find_s_segments {
  my $po = shift;
  my $pseg = undef;
  my $off  = 0;
  my ($wxref,$wxoff,$wxlen,$wsegi, $sid);
  my ($ssegi);
  my $sid2cur = {}; ##-- $sid => [$seg_open,$seg_close]
  my $sid2nsegs = $po->{sid2nsegs};
  %$sid2nsegs = qw();
  my $srcbufr = $po->{srcbufr};
  foreach (@{$po->{w_segs}}) {
    ($wxref,$wxoff,$wxlen,$wsegi, $sid) = @$_;

    if ($sid && ($pseg=$sid2cur->{$sid})
	&& $wxoff >= $off
	&& substr($$srcbufr, $off, ($wxoff-$off)) =~ m{^(?:
							 (?:\s)                  ##-- non-markup
						         |(?:<[^>]*/>)           ##-- empty element
							 |(?:<!--[^>]*-->)       ##-- comment
							 |(?:<c\b[^>]*>\s*</c>)  ##-- c (whitespace-only)
							 #|(?:<w\b[^>]*>\s*</w>)  ##-- w-tag (e.g. from OCR)
							)*$}sx
       ) {
      ##-- extend current <s>-segment to enclose this <w>-segment
      $pseg->[1][$SEG_SEND] = 0;
      $pseg->[1]            = $_;
      $_->[$SEG_SEND]       = 1;
     }
    elsif ($sid) {
      ##-- new <s>-segment beginning at this <w>-segment
      $_->[$SEG_SBEGI] = ++$sid2nsegs->{$sid};
      $_->[$SEG_SEND] = 1;
      if ($pseg) {
	$pseg->[0][$SEG_SNXTI] = $_->[$SEG_SBEGI];
	$_->[$SEG_SPRVI]       = $pseg->[0][$SEG_SBEGI];
      }
      $sid2cur->{$sid} = [$_,$_];
    }
    else {
      ##-- no <s>-segment at all at this <w>-segment
      $_->[$SEG_SBEGI] = $_->[$SEG_SEND] = undef;
    }

    $off = $wxoff + $wxlen;
  }
}


##----------------------------------------------------------------------
## Subs: splice segments into base document

## undef = splice_segments(\$outbufr)
##  + splices final segments from @w_segs=@{$po->{w_segs}} into $srcbuf; dumping output to $outfh
##  + sorts @w_segs on xml offset ($SEG_OFF)
sub splice_segments {
  my ($po,$outbufr) = @_;
  $outbufr  = \(my $outbuf='') if (!defined($outbufr));
  $$outbufr = '';
  my ($xref_this,$xref_prev,$xref_next);
  my ($xref,$xoff,$xlen,$segi, $sid,$sbegi,$sprvi,$snxti,$send);
  my ($nwsegs,$nssegs);
  my $off = 0;
  my ($wIdAttr,$sIdAttr)  = @$po{qw(wIdAttr sIdAttr)};
  my ($w_segs,$wid2nsegs,$srcbufr) = @$po{qw(w_segs wid2nsegs srcbufr)};

  @$w_segs = sort {$a->[$SEG_XOFF] <=> $b->[$SEG_XOFF]} @$w_segs; ##-- sort in source-document order
  foreach (@$w_segs) {
    ##-- common vars
    ($xref,$xoff,$xlen,$segi, $sid,$sbegi,$sprvi,$snxti,$send) = @$_;
    $nwsegs  = $wid2nsegs->{$xref};

    ##-- splice in prefix
    $$outbufr .= substr($$srcbufr, $off, ($xoff-$off));

    ##-- maybe splice in <s>-start-tag
    if ($sbegi) {
      if (!$sprvi && !$snxti) {
	##-- //s-start-tag: single-element item
	$$outbufr .= "<s $sIdAttr=\"$sid\">";
      } else {
	##-- //s-start-tag: multi-segment item
	$xref_this = "${sid}".($sprvi ? "_$sbegi" : '');
	$xref_prev = "${sid}".(($sprvi||1)==1 ? '' : "_${sprvi}");
	$xref_next = "${sid}_".($snxti||'');

	if (!$sprvi) {
	  ##-- //s-start-tag: multi-segment item: initial segment
	  $$outbufr .= "<s part=\"I\" $sIdAttr=\"$xref_this\" next=\"$xref_next\">";
	} elsif (!$snxti) {
	  ##-- //s-start-tag: multi-segment item: final segment
	  $$outbufr .= "<s part=\"F\" $sIdAttr=\"$xref_this\" prev=\"$xref_prev\">"; #." $s_refAttr=\"#$xref\""
	} else {
	  ##-- //s-start-tag: multi-segment item: middle segment
	  $$outbufr .= "<s part=\"M\" $sIdAttr=\"$xref_this\" prev=\"$xref_prev\" next=\"$xref_next\">"; #." $s_refAttr=\"#$xref\""
	}
      }
    }

    ##-- splice in <w>-start-tag
    ## + CHANGED Tue, 20 Mar 2012 16:28:51 +0100 (moocow): dta-tokwrap v0.28
    ##    - use @prev,@next attributes for segmentation
    ##    - keep old @part attributes for compatibility (but throw out $w_refAttr ("n"))
    if ($nwsegs==1) {
      ##-- //w-start-tag: single-segment item
      $$outbufr .= "<w $wIdAttr=\"$xref\">";
    } else {
      ##-- //w-start-tag: multi-segment item
      $xref_this = "${xref}".($segi>1 ? ("_".($segi-1)) : '');
      $xref_prev = "${xref}".($segi>2 ? ("_".($segi-2)) : '');
      $xref_next = "${xref}_${segi}";

      if ($segi==1) {
	##-- //w-start-tag: multi-segment item: initial segment
	$$outbufr .= "<w part=\"I\" $wIdAttr=\"$xref_this\" next=\"$xref_next\">";
      } elsif ($segi==$nwsegs) {
	##-- //w-start-tag: multi-segment item: final segment
	$$outbufr .= "<w part=\"F\" $wIdAttr=\"$xref_this\" prev=\"$xref_prev\">"; #." $w_refAttr=\"#$xref\""
      } else {
	##-- //w-start-tag: multi-segment item: middle segment
	$$outbufr .= "<w part=\"M\" $wIdAttr=\"$xref_this\" prev=\"$xref_prev\" next=\"$xref_next\">"; #." $w_refAttr=\"#$xref\""
      }
    }

    ##-- //w-segment: splice in content and end-tag(s)
    $$outbufr .= (substr($$srcbufr,$xoff,$xlen)
		  ."</w>"
		  .($send ? "</s>" : ''));

    ##-- update offset
    $off = $xoff+$xlen;
  }

  ##-- splice in post-token material
  $$outbufr .= substr($$srcbufr, $off,length($$srcbufr)-$off);
}


##==============================================================================
## Methods: Document Processing
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->addws($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    xmldata => $xmldata,   ##-- (input) source xml file
##    xtokdata => $xtokdata, ##-- (input) standoff xml-ified tokenizer output: data
##    xtokfile => $xtokfile, ##-- (input) standoff xml-ified tokenizer output: file (only if $xtokdata is missing)
##    cwsdata  => $cwsdata,  ##-- (output) back-spliced xml data
##    addws_stamp0 => $f,    ##-- (output) timestamp of operation begin
##    addws_stamp  => $f,    ##-- (output) timestamp of operation end
##    cwsdata_stamp => $f,   ##-- (output) timestamp of operation end
sub addws {
  my ($po,$doc) = @_;
  $doc->setLogContext();

  ##-- log, stamp
  $po->vlog($po->{traceLevel},"addws()");
  $doc->{addws_stamp0} = timestamp();

  ##-- sanity check(s)
  $po = $po->new() if (!ref($po));
  ##
  $doc->loadXmlData() if (!$doc->{xmldata}); ##-- slurp source buffer
  $po->logconfess("addws(): no xmldata key defined") if (!$doc->{xmldata});
  my $xprs = $po->xmlParser() or $po->logconfes("addws(): could not get XML parser");

  ##-- splice: parse standoff
  $po->vlog($po->{traceLevel},"addws(): parse standoff xml");
  if (defined($doc->{xtokdata})) {
    $xprs->parse($doc->{xtokdata});
  } else {
    $xprs->parsefile($doc->{xtokfile});
  }

  ##-- compute //s segments
  $po->vlog($po->{traceLevel},"addws(): search for //s segments");
  $po->{srcbufr} = \$doc->{xmldata};
  $po->find_s_segments();

  ##-- report final assignment
  if (defined($po->{addwsInfo})) {
    my $nseg_w = scalar(@{$po->{w_segs}});
    my $ndis_w = scalar(grep {$_>1} values %{$po->{wid2nsegs}});
    my $pdis_w = ($po->{nw}==0 ? 'NaN' : 100*$ndis_w/$po->{nw});
    ##
    my $nseg_s = 0; $nseg_s += $_ foreach (values %{$po->{sid2nsegs}});
    my $ndis_s = scalar(grep {$_>1} values %{$po->{sid2nsegs}});
    my $pdis_s = ($po->{ns}==0 ? 'NaN' : 100*$ndis_s/$po->{ns});
    ##
    my $dfmt = "%".length($po->{nw})."d";
    $po->vlog($po->{addwsInfo}, sprintf("$dfmt token(s)    in $dfmt segment(s): $dfmt discontinuous (%5.1f%%)", $po->{nw}, $nseg_w, $ndis_w, $pdis_w));
    $po->vlog($po->{addwsInfo}, sprintf("$dfmt sentence(s) in $dfmt segment(s): $dfmt discontinuous (%5.1f%%)", $po->{ns}, $nseg_s, $ndis_s, $pdis_s));
  }

  ##-- output: splice in <w> and <s> segments
  $po->vlog($po->{traceLevel},"addws(): creating $doc->{cwsfile}");
  $po->splice_segments(\$doc->{cwsdata});
  ref2file(\$doc->{cwsdata},$doc->{cwsfile},{binmode=>(utf8::is_utf8($doc->{cwsdata}) ? ':utf8' : ':raw')});

  ##-- finalize
  $doc->{addws_stamp} = timestamp(); ##-- stamp
  return $doc;
}

1; ##-- be happy
__END__
