## -*- Mode: CPerl; coding: utf-8; -*-

## File: DTA::TokWrap::Processor::idsplice.pm
## Author: Bryan Jurish <jurish@bbaw.de>
## Descript: DTA tokenizer wrappers: base.xml + so.xml -> base+so.xml
##  + splices in attributes and content from selected so.xml into base.xml by id-matching
##  + formerly implemented in external script dtatw-splice.perl

package DTA::TokWrap::Processor::idsplice;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :files :slurp :time :xmlutils :numeric);
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

##==============================================================================
## Constructors etc.
##==============================================================================

## $p = CLASS_OR_OBJ->new(%args)
## %defaults = CLASS->defaults()
##  + static class-dependent defaults
##  + %args, %defaults, %$p:
##    (
##     ##-- configuration options
##     soIgnoreAttrs => \@attrs,	##-- standoff attributes to ignore (default:none)
##     soIgnoreElts  => \%elts,		##-- standoff elements to ignore (default:none)
##     soKeepText    => $keepText,	##-- retain standoff text content? (default:false)
##     soKeepBlanks  => $keepBlanks,	##-- retain standoff whitespace? (default:false)
##     wrapOldContent => $elt,		##-- element in which to wrap old base content (default:undef:none)
##     outbufr => \$buf,		##-- output (string) buffer
##     spliceInfo => $level, 		##-- log-level for summary (default='debug')
##
##     ##-- low-level data
##     xp_so   => $xp_so,	##-- XML::Parser object for standoff file
##     xp_base => $xp_base,	##-- XML::Parser object for base file
##    )
sub defaults {
  my $that = shift;
  return (
	  ##-- inherited
	  $that->SUPER::defaults(),

	  ##-- user attributes
	  soIgnoreAttrs => [],
	  soIgnoreElts  => {},
	  soKeepText    => 0,
	  soKeepBlanks  => 0,
	  wrapOldContent => undef,
	  spliceInfo => 'debug',

	  ##-- low-level
	 );
}

##----------------------------------------------------------------------
## $p = $p->init()
##  compute dynamic object-dependent defaults
sub init {
  my $p = shift;

  ##-- parse: soIgnoreAttrs
  if (defined($p->{soIgnoreAttrs}) && !UNIVERSAL::isa($p->{soIgnoreAttrs},'ARRAY')) {
    if (!ref($p->{soIgnoreAttrs})) {
      $p->{soIgnoreAttrs} = [grep {defined($_)} split(/[\s\,\|]+/,$p->{soIgnoreAttrs})];
    } elsif (UNIVERSAL::isa($p->{soIgnoreAttrs},'HASH')) {
      $p->{soIgnoreAttrs} = [keys %{$p->{soIgnoreAttrs}}];
    } else {
      $p->logconfess("init(): could not parse soIgnoreAttrs=$p->{soIgnoreAttrs} as ARRAY");
    }
  }

  ##-- parse: soIngoreElts
  if (defined($p->{soIgnoreElts}) && !UNIVERSAL::isa($p->{soIgnoreElts},'HASH')) {
    if (!ref($p->{soIgnoreElts})) {
      $p->{soIgnoreElts} = {map {($_=>undef)} grep {defined($_)} split(/[\s\,\|]+/,$p->{soIgnoreElts})};
    } elsif (UNIVERSAL::isa($p->{soIgnoreAttrs},'ARRAY')) {
      $p->{soIgnoreElts} = {map {($_=>undef)} @{$p->{soIgnoreElts}}};
    } else {
      $p->logconfess("init(): could not parse soIgnoreElts=$p->{soIgnoreElts} as HASH");
    }
  }

  return $p;
}

##==============================================================================
## Methods: Utils
##==============================================================================

##----------------------------------------------------------------------
## ($xp_so,$xp_base) = $p->xmlParsers()
##   + returns cached @$p{qw(xp_so xp_base)} if available, otherwise creates new ones
sub xmlParsers {
  my $p = shift;
  return @$p{qw(xp_so xp_base)} if (ref($p) && defined($p->{xp_so}) && defined($p->{xp_base}));

  ##-- labels
  my $prog = ref($p).": ".Log::Log4perl::MDC->get('xmlbase');

  ##--------------------------------------------------------------
  ## closure variables
  my ($_xp, $_elt, %_attrs);
  my @xids = qw();        ##-- stack of nearest-ancestor (xml:)?id values; 1 entry for each currently open element
  my $xid = undef;    	  ##-- (xml:)?id of most recently opened element with an id
  my %so_attrs = qw();	  ##-- %so_attrs   = ($id => \%attrs, ...)
  my %so_content = qw();  ##-- %so_content = ($id => $content, ...)
  my ($soIgnoreAttrs,$soIgnoreElts,$soKeepText,$soKeepBlanks); ##-- options

  ##--------------------------------------------------------------
  ## XML::Parser: standoff

  ##----------------------------
  ## undef = cb_init($expat)
  my $so_cb_init = sub {
    #($_xp) = @_;
    $soIgnoreAttrs = $p->{soIgnoreAttrs} || [];
    $soIgnoreElts  = $p->{soIgnoreElts}  || {};
    $soKeepText    = $p->{soKeepText};
    $soKeepBlanks  = $p->{soKeepBlanks};
    @xids       = qw();
    $xid        = undef;
    %so_attrs   = qw();
    %so_content = qw();

    ##-- debug
    $p->{so_attrs}   = \%so_attrs;
    $p->{so_content} = \%so_content;
    $p->{xids}       = \@xids;
    $p->{xidr}       = \$xid;
  };

  ##----------------------------
  ## undef = cb_start($expat, $elt,%attrs)
  my ($eid);
  my $so_cb_start = sub {
    %_attrs = @_[2..$#_];
    if (defined($eid = $_attrs{'id'} || $_attrs{'xml:id'})) {
      delete(@_attrs{qw(id xml:id),@$soIgnoreAttrs});
      $so_attrs{$eid} = {%_attrs} if (%_attrs);
      $xid = $eid;
    }
    push(@xids,$xid);
    $_[0]->default_current if (!defined($eid) && !exists($soIgnoreElts->{$_[1]}));
  };

  ##----------------------------
  ## undef = cb_end($expat,$elt)
  my $so_cb_end = sub {
    $eid=pop(@xids);
    $xid=$xids[$#xids];
    $_[0]->default_current if (!exists($soIgnoreElts->{$_[1]}) && (!defined($eid) || !defined($xid) || $eid eq $xid));
  };

  ##----------------------------
  ### undef = cb_char($expat,$string)
  my $so_cb_char = sub {
    $_[0]->default_current() if ($soKeepText);
  };

  ##----------------------------
  ## undef = cb_default($expat, $str)
  my $so_cb_default = sub {
    $so_content{$xid} .= $_[0]->original_string if (defined($xid));
  };

  ##----------------------------
  ## undef = cb_final($expat)
  my ($content);
  my $so_cb_final = sub {
    if (!$soKeepBlanks) {
      foreach $xid (keys %so_content) {
	$content = $so_content{$xid};
	$content =~ s/\s+/ /sg;
	if ($content =~ /^\s*$/) {
	  delete($so_content{$xid});
	} else {
	  $so_content{$xid} = $content;
	}
      }
    }
  };

  ##----------------------------
  ## XML::Parser: standoff: init
  $p->{xp_so} = XML::Parser->new(
				 ErrorContext => 1,
				 ProtocolEncoding => 'UTF-8',
				 #ParseParamEnt => '???',
				 Handlers => {
					      Init  => $so_cb_init,
					      Start => $so_cb_start,
					      End   => $so_cb_end,
					      Char  => $so_cb_char,
					      Default => $so_cb_default,
					      Final => $so_cb_final,
					     },
			   )
    or $p->logconfess("couldn't create XML::Parser for standoff file");


  ##--------------------------------------------------------------
  ## XML::Parser: base

  my ($n_merged_attrs,$n_merged_content,$old_content_elt,@wrapstack);
  my ($outbufr);

  ##----------------------------
  ## undef = cb_init($expat)
  my $base_cb_init = sub {
    #($_xp) = @_;
    $n_merged_attrs = 0;
    $n_merged_content = 0;
    $old_content_elt = $p->{wrapOldContent};
    @wrapstack = qw();

    $outbufr = $p->{outbufr};
    $outbufr = $p->{outbufr} = \(my $buf) if (!defined($outbufr));
    $$outbufr = '';

    ##-- debug
    $p->{wrapstack} = \@wrapstack;
    $p->{n_merged_attrs_ref} = \$n_merged_attrs;
    $p->{n_merged_content_ref} = \$n_merged_content;
  };

  ##----------------------------
  ## undef = cb_final($expat)
  my $base_cb_final = sub {
    $p->{nMergedAttrs}   = $n_merged_attrs;
    $p->{nMergedContent} = $n_merged_content;
  };

  ##----------------------------
  ## undef = cb_start($expat, $elt,%attrs)
  my ($is_empty, $so_attrs, $id);
  my $base_cb_start = sub {
    #($_xp,$_elt,%_attrs) = @_;
    %_attrs = @_[2..$#_];
    push(@wrapstack,undef);
    return $_[0]->default_current if (!defined($id=$_attrs{'id'} || $_attrs{'xml:id'}));

    ##-- merge in standoff attributes if available (clobber)
    if (defined($so_attrs=$so_attrs{$id})) {
      %_attrs = (%_attrs, %$so_attrs);
      $n_merged_attrs++;
    }
    $$outbufr .= join(' ',"<$_[1]", map {"$_=\"".xmlesc($_attrs{$_}).'"'} keys %_attrs);

    ##-- merge in standoff content if available (prepend)
    $is_empty = ($_[0]->original_string =~ m|/>$|);
    $wrapstack[$#wrapstack] = $old_content_elt if (!$is_empty);
    if (defined($content=$so_content{$id})) {
      $$outbufr .= ">" . $content . ($is_empty ? "</$_[1]>" : ($old_content_elt ? "<$old_content_elt>" : ''));
      $n_merged_content++;
    }
    elsif ($is_empty) {
      $$outbufr .= "/>";
    }
    else {
      $$outbufr .= ">" . ($old_content_elt ? "<$old_content_elt>" : '');
    }
  };

  ##----------------------------
  ## undef = cb_end($expat, $elt)
  my ($wrap);
  my $base_cb_end = sub {
    #($_xp,$_elt) = @_;
    $wrap = pop(@wrapstack);
    $$outbufr .= "</$wrap>" if ($wrap);
    $_[0]->default_current;
  };

  ##----------------------------
  ## undef = cb_default($expat, $str)
  my $base_cb_default = sub {
    $$outbufr .= $_[0]->original_string;
  };

  ##----------------------------
  ## XML::Parser: standoff: init
  $p->{xp_base} = XML::Parser->new(
				  ErrorContext => 1,
				  ProtocolEncoding => 'UTF-8',
				  #ParseParamEnt => '???',
				  Handlers => {
					       Init    => $base_cb_init,
					       Final   => $base_cb_final,
					       Start   => $base_cb_start,
					       End     => $base_cb_end,
					       Default => $base_cb_default,
					      },
			       )
    or $p->logconfess("couldn't create XML::Parser for base file");


  ##--------------------------------------------------------------
  ## return
  return @$p{qw(xp_so xp_base)};
}

##==============================================================================
## Methods: Simple OO interface

## \$outbuf = $p->splice_buffers(\$baseBuf,\$soBuf)
## \$outbuf = $p->splice_buffers(\$baseBuf,\$soBuf,$basename)
sub splice_buffers {
  my ($p,$basebufr,$sobufr,$basename) = @_;
  Log::Log4perl::MDC->put("xmlbase", $basename) if (defined($basename));

  my ($xp_so,$xp_base) = $p->xmlParsers();

  $p->vlog($p->{traceLevel}, "splice_buffers(): parse standoff buffer");
  $xp_so->parse($$sobufr);

  $p->vlog($p->{traceLevel}, "splice_buffers(): parse base buffer");
  $xp_base->parse($$basebufr);

  $p->vlog($p->{spliceInfo}, $_) foreach ($p->summary($basename));
  return $p->{outbufr};
}

## \$outbuf = $p->splice_files($baseFile,$soFile)
## \$outbuf = $p->splice_files($baseFile,$soFile,$outFile)
sub splice_files {
  my ($p,$basefile,$sofile,$outfile) = @_;
  Log::Log4perl::MDC->put("xmlbase", File::Basename::basename($basefile)) if (defined($basefile));

  my ($xp_so,$xp_base) = $p->xmlParsers();

  $p->vlog($p->{traceLevel}, "splice_files(): parse standoff file '$sofile'");
  $xp_so->parsefile($sofile);

  $p->vlog($p->{traceLevel}, "splice_files(): parse base file '$basefile'");
  $xp_base->parsefile($basefile);

  if ($outfile) {
    $p->vlog($p->{traceLevel}, "splice_files(): dump to output file '$outfile'");
    ref2file($p->{outbufr}, $outfile, {binmode=>(utf8::is_utf8(${$p->{outbufr}}) ? ':utf8' : ':raw')})
      or $p->logconfess("could not save output file '$outfile': $!");
  }

  $p->vlog($p->{spliceInfo}, $_) foreach ($p->summary($basefile,$sofile));
  return $p->{outbufr};
}


## @msgs = $p->summary()
## @msgs = $p->summary($baselabel)
## @msgs = $p->summary($baselabel,$solabel)
##  + info messages
sub summary {
  my ($p,$baselab,$solab) = @_;
  return (
	  ("merged " . pctstr($p->{nMergedAttrs}, scalar(keys %{$p->{so_attrs}}), 'attribute-lists')
	   .' and '  . pctstr($p->{nMergedContent}, scalar(keys %{$p->{so_content}}), 'content-strings')
	   .($solab ? " from $solab" : '')
	   .($baselab ? " into $baselab" : '')
	  ),
	 );
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
  my ($p,$doc) = @_;
  $doc->setLogContext();

  ##-- log, stamp
  $p->vlog($p->{traceLevel},"addws()");
  $doc->{addws_stamp0} = timestamp();

  ##-- sanity check(s)
  $p = $p->new() if (!ref($p));
  ##
  $doc->loadXmlData() if (!$doc->{xmldata}); ##-- slurp source buffer
  $p->logconfess("addws(): no xmldata key defined") if (!$doc->{xmldata});
  my $xprs = $p->xmlParser() or $p->logconfes("addws(): could not get XML parser");

  ##-- splice: parse standoff
  $p->vlog($p->{traceLevel},"addws(): parse standoff xml");
  if (defined($doc->{xtokdata})) {
    $xprs->parse($doc->{xtokdata});
  } else {
    $xprs->parsefile($doc->{xtokfile});
  }

  ##-- compute //s segments
  $p->vlog($p->{traceLevel},"addws(): search for //s segments");
  $p->{srcbufr} = \$doc->{xmldata};
  $p->find_s_segments();

  ##-- report final assignment
  if (defined($p->{addwsInfo})) {
    my $nseg_w = scalar(@{$p->{w_segs}});
    my $ndis_w = scalar(grep {$_>1} values %{$p->{wid2nsegs}});
    my $pdis_w = ($p->{nw}==0 ? 'NaN' : 100*$ndis_w/$p->{nw});
    ##
    my $nseg_s = 0; $nseg_s += $_ foreach (values %{$p->{sid2nsegs}});
    my $ndis_s = scalar(grep {$_>1} values %{$p->{sid2nsegs}});
    my $pdis_s = ($p->{ns}==0 ? 'NaN' : 100*$ndis_s/$p->{ns});
    ##
    my $dfmt = "%".length($p->{nw})."d";
    $p->vlog($p->{addwsInfo}, sprintf("$dfmt token(s)    in $dfmt segment(s): $dfmt discontinuous (%5.1f%%)", $p->{nw}, $nseg_w, $ndis_w, $pdis_w));
    $p->vlog($p->{addwsInfo}, sprintf("$dfmt sentence(s) in $dfmt segment(s): $dfmt discontinuous (%5.1f%%)", $p->{ns}, $nseg_s, $ndis_s, $pdis_s));
  }

  ##-- output: splice in <w> and <s> segments
  $p->vlog($p->{traceLevel},"addws(): creating $doc->{cwsfile}");
  $p->splice_segments(\$doc->{cwsdata});
  ref2file(\$doc->{cwsdata},$doc->{cwsfile},{binmode=>(utf8::is_utf8($doc->{cwsdata}) ? ':utf8' : ':raw')});

  ##-- finalize
  $doc->{addws_stamp} = timestamp(); ##-- stamp
  return $doc;
}

1; ##-- be happy
__END__
