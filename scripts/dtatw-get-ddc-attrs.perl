#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use XML::LibXML;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode encode_utf8 decode_utf8);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;

use strict;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);
our ($help);

##-- vars: I/O
our $txmlfile = undef; ##-- required
our $cxmlfile = "-";   ##-- default: stdin
our $outfile  = "-";   ##-- default: stdout
our $format = 1;       ##-- output format level

##-- selection
our $keep_blanks = 0;
our $do_page = 1;
our $do_rendition = 1;
our $do_xcontext = 1;
our $do_xpath = 0;
our $do_bbox = 1;
our $do_keep_c = 1;
our $do_keep_b = 1;

##-- output attributes
our $rendition_attr = 'xr';
our $xcontext_attr  = 'xc';
our $xpath_attr     = 'xp';
our $page_attr      = 'pb';
our $bbox_attr      = 'bb';

##-- constants: verbosity levels
our $vl_warn     = 1;
our $vl_progress = 2;
our $verbose = $vl_progress;     ##-- print progress messages by default

##-- warnings: specific options
our $warn_on_empty_cids = 1;     ##-- warn on empty //w/@c id-list attribute in txmlfile?

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,
	   'verbose|v=i' => \$verbose,
	   'quiet|q' => sub { $verbose=!$_[1]; },

	   ##-- I/O
	   'keep-blanks|blanks|whitespace|ws!' => \$keep_blanks,
	   'page|pb|p!' => $do_page,
	   'rendition|rend|r!' => \$do_rendition,
	   'xcontext|context|xcon|con|xc!' => \$do_xcontext,
	   'xpath|path|xp!' => \$do_xpath,
	   'coordinates|coords|coord|c|bboxes|bbox|b!' => \$do_bbox,
	   'keep-c|keepc|kc!' => \$do_keep_c,
	   'keep-b|keepb|kb!' => \$do_keep_b,
	   'output|out|o=s' => \$outfile,
	   'format|f!' => \$format,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);

##-- command-line: arguments
($txmlfile, $cxmlfile) = @ARGV;
$txmlfile = '-' if (!$txmlfile);
if (!defined($cxmlfile) || $cxmlfile eq '') {
  ($cxmlfile = $txmlfile) =~ s/\.t\.xml$/.xml/;
  pod2usage({-exitval=>0,-verbose=>0,-msg=>"$prog: could not guess CHR_XML_FILE for T_XML_FILE=$txmlfile"})
    if ($cxmlfile eq $txmlfile);
}

##======================================================================
## Subs: t-xml stuff (*.t.xml)

## $txmldoc = load_txml($txmlfile)
##  + loads and returns xml doc
sub load_txml {
  my $xmlfile = shift;

  ##-- initialize LibXML parser
  my $parser = XML::LibXML->new();
  $parser->keep_blanks($keep_blanks ? 1 : 0);
  $parser->line_numbers(1);

  ##-- load xml
  my $xdoc = $xmlfile eq '-' ? $parser->parse_fh(\*STDIN) : $parser->parse_file($xmlfile);
  die("$prog: could not parse .t.xml file '$xmlfile': $!") if (!$xdoc);

  ##-- ... and just return here
  return $xdoc;
}


##======================================================================
## Subs: cxmlfile stuff (*.chr.xml)

## @stack: stack of element-data hashes
##  + each $edata on stack = {tag=>$tag, rendition=>\%rendition, context=>\%context, ...}
##  + global $edata: current top of stack
##  + $path: current xpath (without numeric positions)
our (@stack,$edata,$xpath,$page);

##-- $cid maps (for //c elements not assigned to any word)
our %cid2cn   = qw();   ##-- %cid2cn  = ($cid=>$cn, ...)
our @cn2cid   = qw();   ##-- @cn2cid  = ([$cn]=>$cid, ...): list of all (//c/@id)s in chr-xml file
our @cn2page  = qw();   ##-- @cn2page = ([$cn]=>$pb_facs,...)
our @cn2bbox  = qw();   ##-- @cn2bbox = ([$cn]=>"$ulx $uly $lrx $lry",...) with $ulx<=$lrx, $uly<=$lry; -1 for undef
our @cn2rend  = qw();   ##-- @cn2rend = ([$cn]=>join(' ',@rendition_keys), ...)
our @cn2xcon  = qw();   ##-- @cn2xcon = ([$cn]=>join(' ',@xcontext_keys), ...)
our @cn2xpath = qw();   ##-- @cn2xpath = ([$cn]=>$xpath, ...) 

## undef = cxml_cb_init($expat)
sub cxml_cb_init {
  #($_xp) = @_;
  @stack = qw();
  $edata = { rendition=>{}, xcontext=>{} };  ##-- current stack item
  $xpath = '';
  $page  = -1;
  @cn2cid   = qw();
  %cid2cn  = qw();
  @cn2page = qw();
  @cn2bbox = qw();
  @cn2rend = qw();
  @cn2xcon = qw();
  @cn2xpath = qw();
}

## undef = cxml_cb_final($expat)
#sub cxml_cb_final {
#  base_flush_segment();
#  return \@w_segs0;
#}

our (%_attrs);
our ($facs,$rendition,$xcontext);
our ($cid,$cn);

our %xcontext_elts = (map {($_=>$_)}
		      qw(text front body back head left foot end argument hi cit fw lg stage speaker)
		     );

## undef = cxml_cb_start($expat, $elt,%attrs)
sub cxml_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  %_attrs = @_[2..$#_];

  ##-- new stack item
  $edata = {%$edata, tag=>$_[1]};
  push(@stack,$edata);
  $xpath .= "/$_[1]";

  ##-- rendition
  if ($do_rendition && defined($rendition=$_attrs{rendition})) {
    $edata->{rendition} = { %{$edata->{rendition}}, map {($_=>undef)} split(' ',$rendition) };
  }

  ##-- tag-dispatch
  if ($_[1] eq 'c' && (defined($cid=$_attrs{'id'}) || defined($cid=$_attrs{'xml:id'}))) {
    ##-- //c assigned to some //w: extract data
    push(@cn2cid,$cid);
    $cid2cn{$cid}  = $cn = $#cn2cid;
    $cn2page[$cn]  = $page  if ($do_page);
    $cn2rend[$cn]  = join(' ', keys(%{$edata->{rendition}})) if ($do_rendition);
    $cn2xcon[$cn]  = join(' ', keys(%{$edata->{xcontext}}))  if ($do_xcontext);
    $cn2bbox[$cn]  = join(' ', map {defined($_) ? $_ : -1} @_attrs{qw(ulx uly lrx lry)}) if ($do_bbox);
    $cn2xpath[$cn] = $xpath if ($do_xpath);
  }
  elsif ($do_xcontext && defined($xcontext=$xcontext_elts{$_[1]})) {
    ##-- structural context: element-based
    $edata->{xcontext} = { %{$edata->{xcontext}}, $xcontext=>undef };
  }
  elsif ($do_xcontext && $_[1] eq 'note') {
    ##-- structural context: marginalia: subdivide by placement
    $xcontext = 'note_'.($_attrs{'place'}||'other');
    $edata->{xcontext} = { %{$edata->{xcontext}}, $xcontext=>undef };
  }
  elsif ($do_page && $_[1] eq 'pb' && defined($facs=$_attrs{'facs'})) {
    ##-- page break
    ($page=$facs) =~ s/^\#?f?0*//;
  }

  return;
}

## undef = cxml_cb_end($expat, $elt)
sub cxml_cb_end {
  #($_xp,$_elt) = @_;
  substr($xpath,-length($edata->{tag})-1) = '';
  pop(@stack);
  $edata = $stack[$#stack];
}

### undef = cxml_cb_char($expat,$string)
#sub cxml_cb_char {
#  $_[0]->default_current;
#}

## undef = cxml_cb_default($expat, $str)
#sub cxml_cb_default {
#  $outfh->print($_[0]->original_string);
#}

##======================================================================
## Subs: merge

## $wgood = apply_word($wnod)
## $wgood = apply_word($wnod,\@cids)
## $wgood = apply_word($wnod,\@cids,$bbsingle)
##  + populates globals: ($wnod,$wid,$cids,@cids,$wpage,$wrend,$wcon,$wxpath,@wbboxes)
my ($wnod,$wid,$cids,@cids,@cns,$wpage,$wrend,$wcon,$wxpath,@cn2wnod,$bbsingle);
my ($wcns,@wbboxes,@cbboxes,$cbbox,$wbbox);
sub apply_word {
  ($wnod,$cids,$bbsingle) = @_;

  ##-- get id
  if (!defined($wid=$wnod->getAttribute('id'))) {
    ##-- ...and ensure it's in the raw '//w/@id' attribute and not 'xml:id'
    if (!defined($wid=$wnod->getAttribute('xml:id'))) {
      warn("$0: //w node without \@id attribute at $txmlfile line ", $wnod->line_number, "\n")
	if ($verbose >= $vl_warn);
    }
    $wnod->getAttributeNode('xml:id')->setNamespace('','');
  }

  ##-- get cids
  $cids = $wnod->getAttribute('c') || $wnod->getAttribute('cs') || '' if (!defined($cids));
  @cids = ref($cids) ? @$cids : cidlist($cids);
  @cns  = grep {defined($_)} @cid2cn{@cids};
  if (!@cids && $warn_on_empty_cids && $verbose >= $vl_warn) {
    ##-- $wnod without a //c/@id list
    ##   + this happens e.g. for 'FORMEL' inserted via DTA::TokWrap::mkbx0 'hint_replace_xpaths'
    ##   + push these to @wnoc and try to fudge them in a second pass
    warn("$0: no //c/\@id list for //w at $txmlfile line ", $wnod->line_number, "\n");
  }
  elsif (!@cns) {
    warn("$0: invalid //c/\@id list for //w at $txmlfile line ", $wnod->line_number, "\n")
      if ($verbose >= $vl_warn);
  }

  ##-- compute & assign: rendition (undef -> '')
  if ($do_rendition) {
    $wrend = join(' ', luniq(map {split(' ',($cn2rend[$_]||''))} @cns)) || '';
    $wnod->setAttribute($rendition_attr, $wrend);
  }

  ##-- compute & assign: structural context: xcontext (undef -> '')
  if ($do_xcontext) {
    $wcon = join(' ', luniq(map {split(' ',($cn2xcon[$_]||''))} @cns)) || '';
    $wnod->setAttribute($xcontext_attr, $wcon);
  }

  ##-- compute & assign: xpath (undef -> '/..' (== empty node set))
  if ($do_xpath) {
    $wxpath = @cns ? $cn2xpath[$cns[0]] : undef;
    $wxpath = '/..' if (!$wxpath);
    $wxpath =~ s|/c$||i;   ##-- prune final 'c'-element from //w xpath
    $wnod->setAttribute($xpath_attr, $wxpath);
  }

  ##-- compute & assign: page (undef -> -1; non-empty @cids only)
  if ($do_page) {
    $wpage = @cns ? $cn2page[$cns[0]] : undef;
    $wpage = -1 if (!defined($wpage));
    $wnod->setAttribute($page_attr, defined($wpage) ? $wpage : '-1');
  }

  ##-- compute & assign: bbox (undef -> ''; non-empty @cids only)
  if ($do_bbox && @cns) {
    @wbboxes = bboxes(\@cns,$bbsingle);
    $wnod->setAttribute($bbox_attr, join('_', map {join('|',@$_)} @wbboxes));
  }

  ##-- record: cid2wnod
  $cn2wnod[$_] = $wnod foreach (@cns);

  return scalar(@cns);
}

## $xdoc = apply_ddc_attrs($xdoc)
sub apply_ddc_attrs {
  my $xdoc = shift;
  my @wnoc = qw(); ##-- $wnods with no //c/@id list

  ##--------------------------------------
  ## apply: pass=1: the "easy" stuff
  my (%cid2wid);
  my $wnods = $xdoc->findnodes('//w');
  foreach $wnod (@$wnods) {
    push(@wnoc,$wnod) if (!apply_word($wnod));
  }

  ##--------------------------------------
  ## apply: pass=2: words without //c/@id lists
  my ($wprev,$wnext, @cprev,@cnext, $bbprev,$bbnext,@bbprev,@bbnext);
  foreach $wnod (@wnoc) {
    #$wid = $wnod->getAttribute('id') || next; ##-- skip //w nodes without ids

    ##-- get neighbors
    $wprev = $wnod->findnodes('preceding::w[1]')->[0];
    $wnext = $wnod->findnodes('following::w[1]')->[0];

    ##-- guess: @cids (all unassigned //c/@ids between this word's neighbors)
    @cprev = $wprev ? cidlist($wprev->getAttribute('c')||$wprev->getAttribute('cs')||'') : qw();
    @cnext = $wnext ? cidlist($wnext->getAttribute('c')||$wnext->getAttribute('cs')||'') : qw();
#    @cns   = (@cprev && @cnext ? (grep {!exists($cn2wnod[$_])} ($cid2cn{$cprev[$#cprev]}..$cid2cn{$cnext[0]})) : qw());
#    @cids  = @cn2cid[@cns];
#
#    ##-- maybe we can apply already
#    if (@cids) {
#      warn("$0: using unclaimed <c>s to guess attributes for <w> at $txmlfile line ", $wnod->line_number, "\n")
#	if ($verbose >= $vl_warn);
#      apply_word($wnod,\@cids,1); ##-- use single-bbox mode for fallbacks
#      next;
#    }

    ##-- fallback: page: from predecessor
    if ($do_page) {
      $wpage = $wprev->getAttribute($page_attr);
      $wpage = -1 if (!defined($wpage) || $wpage eq '');
      $wnod->setAttribute($page_attr,$wpage);
    }

    ##-- fallback: bbox: from neighbors (without no intervening //c elements available)
    if ($do_bbox) {
      $wbbox = undef;
      if (@cprev && @cnext && ($wprev->getAttribute($page_attr)||'') eq ($wnext->getAttribute($page_attr)||'')) {
	($bbprev = $wprev->getAttribute($bbox_attr)||'') =~ s/^.*_//;
	($bbnext = $wnext->getAttribute($bbox_attr)||'') =~ s/_.*$//;
	@bbprev = split(/\|/,$bbprev);
	@bbnext = split(/\|/,$bbnext);
	if (@bbprev && @bbnext) {
	  print STDERR "$0: using neighbor bboxes to guess bbox for <w> at $txmlfile line ", $wnod->line_number, "\n"
	    if ($verbose >= $vl_warn);
	  if ($bbnext[2] < $bbprev[0]) {
	    ##-- next:RIGHT << prev:LEFT: probably a line-break: use inter-line space
	    $wbbox = [-1,$bbprev[3],-1,$bbnext[1]];
	    @$wbbox[1,3] = @$wbbox[3,1] if ($wbbox->[3] < $wbbox->[1]);
	  } elsif ($bbnext[3] < $bbprev[1]) {
	    ##-- next:BOTTOM >> prev:TOP: probably a column-break: use inter-column space
	    $wbbox = [$bbprev[2],-1,$bbnext[0],-1];
	    @$wbbox[0,2] = @$wbbox[2,0] if ($wbbox->[2] < $wbbox->[0]);
	  } else {
	    ##-- normal case: use inter-word space
	    $wbbox = [@bbprev[2,3],@bbnext[0,1]];
	    @$wbbox[0,2] = @$wbbox[2,0] if ($wbbox->[2] < $wbbox->[0]);
	    @$wbbox[1,3] = @$wbbox[3,1] if ($wbbox->[3] < $wbbox->[1]);
	  }
	}
      }
      warn("$0: could not guess bbox for <w> at $txmlfile line ", $wnod->line_number, "\n")
	if (!$wbbox && $verbose >= $vl_warn);
      $wnod->setAttribute($bbox_attr, join('|', ($wbbox ? @$wbbox : (-1,-1,-1,-1))));
    }
  }

  ##--------------------------------------
  ## apply: pass=3: remove 'c' attributes
  if (!$do_keep_c) {
    foreach $wnod (@$wnods) {
      $wnod->removeAttribute('c');
      $wnod->removeAttribute('cs');
    }
  }
  if (!$do_keep_b) {
    foreach $wnod (@$wnods) {
      $wnod->removeAttribute('b');
    }
  }

  return $xdoc;
}

##======================================================================
## Subs: generic

## @uniq = luniq(@list)
my ($lu_tmp);
sub luniq {
  $lu_tmp=undef;
  return map {(defined($lu_tmp) && $lu_tmp eq $_ ? qw() : ($lu_tmp=$_))} sort @_;
}

## @cids = cidlist($cids_str)
##-- expand compressed //c/@id lists, also accepts old-style space-separated id-lists
sub cidlist {
  map {
    (m/^(.*)c([0-9]+)\+([0-9]+)$/
     ? (map {$1.'c'.$_} ($2..($2+$3-1)))
     : $_)
  } split(' ',$_[0])
}

## @bboxes = bboxes(\@cns)
## @bboxes = bboxes(\@cns,$single=0)
##  + gets list of word bounding boxes @bboxes=($bbox1,$bbox2,...)
##    for a "word" composed of the characters in //c/@id array-ref \@cids
##  + each bbox $bbox in @bboxes is of the form
##      $bbox=[$ulx,$uly,$lrx,$lry]
##    with $ulx<=$lrx, $uly<=$lry; where a coordinate of -1 indicates undefined
##  + if $single is true, at most a single bbox will be returned, otherwise
##    line- and column-breaks will be heuristically detected
sub bboxes {
  ($wcns,$bbsingle) = @_;
  @wbboxes = qw();
  return @wbboxes if (!$wcns || !@$wcns);
  @cbboxes = map {[split(' ',$cn2bbox[$_])]} grep {$cn2page[$_] eq $cn2page[$wcns->[0]]} @$wcns;
  $wbbox   = undef;
  foreach $cbbox (@cbboxes) {
    #($ulx,$uly,$lrx,$lry)=@$cbbox;
    next if (grep {$_ < 0} @$cbbox); ##-- skip //c bboxes with bad values
    if (!$wbbox) {
      ##-- initial bbox
      @wbboxes = ($wbbox=[@$cbbox]);
      next;
    } elsif (!$bbsingle && $cbbox->[2] < $wbbox->[0]) {
      ##-- character:RIGHT << word:LEFT: probably a line-break: new word bbox
      push(@wbboxes, $wbbox=[@$cbbox]);
    } elsif (!$bbsingle && $cbbox->[3] < $wbbox->[1]) {
      ##-- character:BOTTOM >> word:TOP: probably a column-break: new word bbox
      push(@wbboxes, $wbbox=[@$cbbox]);
    } else {
      ##-- extend current word bbox if required
      $wbbox->[0] = $cbbox->[0] if ($cbbox->[0] < $wbbox->[0]);
      $wbbox->[1] = $cbbox->[1] if ($cbbox->[1] < $wbbox->[1]);
      $wbbox->[2] = $cbbox->[2] if ($cbbox->[2] > $wbbox->[2]);
      $wbbox->[3] = $cbbox->[3] if ($cbbox->[3] > $wbbox->[3]);
    }
  }
  return @wbboxes;
}


##======================================================================
## MAIN

##-- scan .chr.xml file and grab attributes
print STDERR "$prog: scanning chr-xml file '$cxmlfile'...\n"
  if ($verbose>=$vl_progress);
our $xp_cxml = XML::Parser->new(
				ErrorContext => 1,
				ProtocolEncoding => 'UTF-8',
				#ParseParamEnt => '???',
				Handlers => {
					     Init   => \&cxml_cb_init,
					     #XmlDecl => \&cxml_cb_xmldecl,
					     #Char  => \&cxml_cb_char,
					     Start  => \&cxml_cb_start,
					     End    => \&cxml_cb_end,
					     #Default => \&cxml_cb_default,
					     #Final   => \&cxml_cb_final,
					    },
			       )
  or die("$prog: couldn't create XML::Parser for chr-xml file '$cxmlfile'");
$xp_cxml->parsefile($cxmlfile);

##-- grab .t.xml file into a libxml doc & pre-index some data
print STDERR "$prog: loading t-xml file '$txmlfile'...\n"
  if ($verbose>=$vl_progress);
our $xdoc = load_txml($txmlfile);

##-- apply attributes from .chr.xml file to .t.xml file
print STDERR "$prog: applying DDC-relevant attributes...\n"
  if ($verbose>=$vl_progress);
$xdoc = apply_ddc_attrs($xdoc);

##-- dump
print STDERR "$prog: dumping output file '$outfile'...\n"
  if ($verbose>=$vl_progress);
($outfile eq '-' ? $xdoc->toFH(\*STDOUT,$format) : $xdoc->toFile($outfile,$format))
  or die("$0: failed to write output file '$outfile': $!");






__END__

=pod

=head1 NAME

dtatw-get-ddc-attrs.perl - get DDC-relevant attributes from DTA::TokWrap files

=head1 SYNOPSIS

 dtatw-get-ddc-attrs.perl [OPTIONS] T_XML_FILE [CHR_XML_FILE=T_XML_FILE:.t.xml=.xml]

 General Options:
  -help                  # this help message
  -verbose LEVEL         # set verbosity level (0<=LEVEL<=1)
  -quiet                 # be silent

 I/O Options:
  -blanks , -noblanks    # don't/do ignore 'ignorable' whitespace in T_XML_FILE file (default=ignored)
  -page   , -nopage      # do/don't extract //w/@page attributes (default=do)
  -rend   , -norend      # do/don't extract //w/@rendition attributes (default=do)
  -xcon   , -noxcon      # do/don't extract //w/@xcontext attributes (default=do)
  -xpath  , -noxpath     # do/don't extract //w/@xpath attributes (default=do)
  -bbox   , -nobbox      # do/don't extract //w/@bbox attributes (default=do)
  -keep-c , -nokeep-c    # do/don't keep existing //w/@c and //w/@cs attributes (default=keep)
  -keep-b , -nokeep-b    # do/don't keep existing //w/@b attributes (default=keep)
  -output FILE           # specify output file (default='-' (STDOUT))

=cut

##------------------------------------------------------------------------------
## Options and Arguments
##------------------------------------------------------------------------------
=pod

=head1 OPTIONS AND ARGUMENTS

Not yet written.

=cut

##------------------------------------------------------------------------------
## Description
##------------------------------------------------------------------------------
=pod

=head1 DESCRIPTION

Splice DDC-relevant attributes from DTA *.chr.xml files into DTA::TokWrap *.t.xml files.

=cut

##------------------------------------------------------------------------------
## See Also
##------------------------------------------------------------------------------
=pod

=head1 SEE ALSO

L<dtatw-add-c.perl(1)|dtatw-add-c.perl>,
L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
L<dtatw-add-w.perl(1)|dtatw-add-w.perl>,
L<dtatw-add-s.perl(1)|dtatw-add-s.perl>,
L<dtatw-splice.perl(1)|dtatw-splice.perl>,
L<dtatw-rm-c.perl(1)|dtatw-rm-c.perl>,
...

=cut

##------------------------------------------------------------------------------
## Footer
##------------------------------------------------------------------------------
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=cut
