#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use XML::LibXML;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode encode_utf8 decode_utf8);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use Unicruft;
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

##-- constants (hacks)
our $PAGE_BOTTOM_Y = 50001;
our $PAGE_TOP_Y = 1;
our $MAX_FORMULA_PIX = 1024; ##-- any formula bboxes higher $MAX_FORMULA_PIX are chucked
our $MIN_FORMULA_PIX = 100;  ##-- formula bboxes shorter than $MIN_FORMULA_PIX are extended
our $CN2WN_BITS = 32;

##-- selection
our $keep_blanks = 0;
our $do_page = 1;
our $do_line = 1;
our $do_rendition = 1;
our $do_xcontext = 1;
our $do_xpath = 1;
our $do_bbox = 1;
our $do_unicruft = 1;
our $do_keep_c = 0;
our $do_keep_b = 0;

##-- output attributes
our $rendition_attr = 'xr';
our $xcontext_attr  = 'xc';
our $xpath_attr     = 'xp';
our $page_attr      = 'pb';
our $line_attr      = 'lb';
our $bbox_attr      = 'bb';
our $unicruft_attr  = 'u';
our $formula_text   = ''; ##-- output text for //formula elements (undef: no change)

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
	   'page|pb|p!' => \$do_page,
	   'line|lb|l!' => \$do_line,
	   'rendition|rend|xr|r!' => \$do_rendition,
	   'xcontext|context|xcon|con|xc!' => \$do_xcontext,
	   'xpath|path|xp!' => \$do_xpath,
	   'coordinates|coords|coord|c|bboxes|bbox|bb|b!' => \$do_bbox,
	   'unicruft|cruft|u!' => \$do_unicruft,
	   'keep-c|keepc|kc!' => \$do_keep_c,
	   'keep-b|keepb|kb!' => \$do_keep_b,
	   'formula-text|ft:s' => \$formula_text,
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

##-- sanity checks
$do_page = 1 if ($do_bbox);
$do_line = 1 if ($do_bbox);

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
## Subs: character record packing

##-- page packing: formats
our %c_packas =
  (
   cn => 'l',
   pb => 'l',
   lb => 's',
   (map {($_=>'l')} qw(ulx uly lrx lry)),
   (map {($_=>'Z*')} qw(elt id xr xc xp)),
  );
our @c_pkeys = (
		'elt', 'id', 'cn',
		($do_page ? 'pb' : qw()),
		($do_line ? 'lb' : qw()),
		($do_bbox ? qw(ulx uly lrx lry) : qw()),
		($do_rendition ? 'xr' : qw()),
		($do_xcontext ? 'xc' : qw()),
		($do_xpath ? 'xp' : qw()),
	       );
our $c_pack  = join('',map {$c_packas{$_}} @c_pkeys);

## $c_packed = c_pack(\%c)
sub c_pack {
  return undef if (!defined($_[0]));
  return pack($c_pack, map {defined($_) ? $_ : ''} @{$_[0]}{@c_pkeys});
}

## \%c = c_unpack($c_packed)
my ($_c_unpack_tmp);
sub c_unpack {
  return undef if (!defined($_[0]));
  $_c_unpack_tmp = {};
  @$_c_unpack_tmp{@c_pkeys} = unpack($c_pack,$_[0]);
  return $_c_unpack_tmp;
}

##======================================================================
## Subs: cxmlfile stuff (*.chr.xml)

## @stack: stack of element-data hashes
##  + each $edata on stack = {tag=>$tag, rendition=>\%rendition, context=>\%context, ...}
##  + global $edata: current top of stack
##  + $path: current xpath (without numeric positions)
our (@stack,$edata,$xpath,$page,$line);

##-- $cid maps (for //c elements not assigned to any word)
our %cid2cn   = qw();   ##-- %cid2cn  = ($cid=>$cn, ...)

##-- $c_packed = $cn2packed[$cn]
## + with $cdata_packed = c_pack(%cdata)
## + and  %cdata        = c_unpack($cdata_packed)
our @cn2packed = qw();

## undef = cxml_cb_init($expat)
sub cxml_cb_init {
  #($_xp) = @_;
  @stack = qw();
  $edata = { rendition=>{}, xcontext=>{} };  ##-- current stack item
  $xpath = '';
  $page  = -1;
  $line  =  1;
  %cid2cn  = qw();
  @cn2packed = qw();
}

## undef = cxml_cb_final($expat)
#sub cxml_cb_final {
#  base_flush_segment();
#  return \@w_segs0;
#}

our (%_attrs,%_c);
our ($facs,$rendition,$xcontext);
our ($cid,$cn);

our %xcontext_elts = (map {($_=>$_)}
		      qw(text front body back head left foot end argument hi cit fw lg stage speaker formula table)
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
  if ($_[1] eq 'c' || $_[1] eq 'formula') {
    ##-- //c assigned to some //w: extract data
    $cid = $_attrs{'id'} || $_attrs{'xml:id'} || '$'.uc($_[1]).':'.($_[0]->current_byte).'$';
    $cn  = scalar(@cn2packed);
    %_c = (
	   %_attrs,
	   elt=>$_[1],
	   id=>$cid,
	   cn=>$cn,
	   pb=>$page,
	   lb=>$line,
	   ($do_rendition ? (xr=>join(' ', keys %{$edata->{rendition}})) : qw()),
	   ($do_xcontext  ? (xc=>join(' ', keys %{$edata->{xcontext}})) : qw()),
	   ($do_xpath     ? (xp=>$xpath) : qw()),
	  );
    $_c{$_} = -1 foreach (grep {!defined($_c{$_})} qw(ulx uly lrx lry));
    push(@cn2packed,c_pack(\%_c));
    $cid2cn{$cid} = $cn;
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
  elsif ($do_page && $_[1] eq 'pb') {
    ##-- page break
    ($page=$facs) =~ s/^\#?f?0*// if (defined($facs=$_attrs{'facs'}));
    $line = 1;
  }
  elsif ($do_line && $_[1] eq 'lb') {
    ++$line;
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

our ($wnods,@wfml,@wnoc,$cn2wn);

## $xdoc = apply_ddc_attrs($xdoc)
##  + calls apply_word() on all nodes
##  + implements basic fallbacks
sub apply_ddc_attrs {
  my $xdoc = shift;

  ##--------------------------------------
  ## apply: pass=1: the "easy" stuff
  $wnods = $xdoc->findnodes('//w');  ##-- all //w nodes
  @wnoc  = qw();                     ##-- indices in @$wnods: //w nodes with no //c/@id list
  @wfml  = qw();                     ##-- indices in @$wnods: formula //w nodes
  $cn2wn = '';                       ##-- maps //c indices to //w indices of claiming wnod ("good" wnods only)
  my ($wi);
  for ($wi=0; $wi <= $#$wnods; $wi++) {
    apply_word($wi);
  }

  ##--------------------------------------
  ## apply: pass=2: formulae
  if ($do_bbox) {
    my ($c0,$wnod,@cs,@lprev_cs,@lnext_cs,$yprev,$ynext);
    my @clist_context = (1..1);
    foreach $wi (@wfml) {
      ##-- get //c list
      $wnod = $wnods->[$wi];
      @cs = grep {defined($_)} clist($wnod->getAttribute('c') || $wnod->getAttribute('cs') || '');
      next if (!defined($c0=$cs[0]));

      ##-- get characters by surrounding line(s)
      @lprev_cs = grep {$_->{elt} eq 'c' && vec($cn2wn,$_->{cn},$CN2WN_BITS)} map {clist_byline($c0->{pb}, $c0->{lb}-$_, $c0->{cn})} @clist_context;
      @lnext_cs = grep {$_->{elt} eq 'c' && vec($cn2wn,$_->{cn},$CN2WN_BITS)} map {clist_byline($c0->{pb}, $c0->{lb}+$_, $c0->{cn})} @clist_context;

      ##-- get line bbox (min,max)
      $yprev = lmax(grep {defined($_) && $_>=0} map {$_->{lry}} @lprev_cs);
      $ynext = lmin(grep {defined($_) && $_>=0} map {$_->{uly}} @lnext_cs);

      ##-- defaults
      $yprev = -1 if (!defined($yprev) || $yprev <= 0);
      $ynext = -1 if (!defined($ynext) || $ynext <= 0);

      ##-- maximum bbox size hack
      if ($ynext>=0 && $yprev>=0 && abs($ynext-$yprev) > $MAX_FORMULA_PIX) {
	$yprev=$ynext=-1;
      }

      ##-- top/bottom of page
      if ($yprev >= 0 && ($ynext < 0 || !@lnext_cs)) {
	$ynext = $PAGE_BOTTOM_Y;
      }
      elsif ($ynext >= 0 && ($yprev < 0 || !@lprev_cs)) {
	$yprev = $PAGE_TOP_Y;
      }

      ##-- bbox sanity condition
      ($yprev,$ynext) = ($ynext,$yprev) if ($ynext>=0 && $yprev>=0 && $ynext < $yprev);

      ##-- minimum-height check
      if ($yprev>=0 && $ynext>=0 && abs($ynext-$yprev)<$MIN_FORMULA_PIX) {
	my $growby = ($MIN_FORMULA_PIX - abs($ynext-$yprev))/2;
	$yprev -= $growby;
	$ynext += $growby;
      }

      ##-- assign line-based bbox (if available)
      warn("$0: could not guess bbox for formula <w> with id ", ($wnod->getAttribute('id')||'?'), " at $txmlfile line ", $wnod->line_number, "\n")
	if ($verbose >= $vl_warn && ($yprev<0 && $ynext<0));

      $wnod->setAttribute($bbox_attr, join('|', (-1,$yprev,-1,$ynext)));
    }
  }

  ##--------------------------------------
  ## apply: pass=3: remove 'c','b' attributes
  if (!$do_keep_c) {
    foreach (@$wnods) {
      $_->removeAttribute('c');
      $_->removeAttribute('cs');
    }
  }
  if (!$do_keep_b) {
    foreach (@$wnods) {
      $_->removeAttribute('b');
    }
  }

  return $xdoc;
}

## undef = apply_word($w_index)
## undef = apply_word($w_index,\@cids)
## undef = apply_word($w_index,\@cids,$bbsingle)
##  + populates globals: ($wnod,$wid,$cids,@cids,$wpage,$wrend,$wcon,$wxpath,@wbboxes)
my ($wi,$wnod,$wid,$cids,@cids,@cs,$wpage,$wline,$wrend,$wcon,$wxpath,$bbsingle);
my ($wcs,@wbboxes,@cbboxes,$cbbox,$wbbox,$wtxt,$utxt,$w_is_formula);
my (@cn2wnod);
sub apply_word {
  ($wi,$cids,$bbsingle) = @_;
  $wnod = $wnods->[$wi];

  ##-- get id
  if (!defined($wid=$wnod->getAttribute('id'))) {
    ##-- ...and ensure it's in the raw '//w/@id' attribute and not 'xml:id'
    if (defined($wid=$wnod->getAttribute('xml:id'))) {
      $wnod->getAttributeNode('xml:id')->setNamespace('','');
    }
    else {
      ##-- complain if no id is present
      warn("$0: //w node without \@id attribute at $txmlfile line ", $wnod->line_number, "\n")
	if ($verbose >= $vl_warn);
    }
  }

  ##-- get cids
  $cids = $wnod->getAttribute('c') || $wnod->getAttribute('cs') || '' if (!defined($cids));
  @cids = ref($cids) ? @$cids : cidlist($cids);
  @cs   = map {c_unpack($_)} @cn2packed[grep {defined($_)} @cid2cn{@cids}];
  if (!@cids && $warn_on_empty_cids && $verbose >= $vl_warn) {
    ##-- $wnod without a //c/@id list
    ##   + this happens e.g. for 'FORMEL' inserted via DTA::TokWrap::mkbx0 'hint_replace_xpaths'
    ##   + push these to @wnoc and try to fudge them in a second pass
    warn("$0: no //c/\@id list for //w at $txmlfile line ", $wnod->line_number, "\n");
  }
  elsif (!@cs) {
    warn("$0: invalid //c/\@id list for //w at $txmlfile line ", $wnod->line_number, "\n")
      if ($verbose >= $vl_warn);
  }

  ##-- detect: formula
  $w_is_formula = (@cs && $cs[0]{elt} eq 'formula') || (@cids && $cids[0] =~ m/\$FORMULA:[0-9]+\$$/);

  ##-- compute & assign: formula text (non-empty @cids only)
  if ($formula_text ne '' && $w_is_formula) {
    $wnod->setAttribute('t',$formula_text);
  }

  ##-- compute & assign: unicruft
  if ($do_unicruft) {
    $wtxt = $wnod->getAttribute('t') || $wnod->getAttribute('text') || '';
    $wtxt = decode_utf8($wtxt) if (!utf8::is_utf8($wtxt));
    if ($wtxt =~ m(^[\x{00}-\x{ff}\p{Latin}\p{IsPunct}\p{IsMark}]*$)) {
      $utxt = decode('latin1',Unicruft::utf8_to_latin1_de($wtxt));
    } else {
      $utxt = $wtxt;
    }
    $wnod->setAttribute($unicruft_attr,$utxt);
  }

  ##-- compute & assign: rendition (undef -> '-')
  if ($do_rendition) {
    $wrend = join('|', luniq(map {s/^\#//; $_} map {split(' ',$_->{xr})} @cs)) || '';
    $wnod->setAttribute($rendition_attr, $wrend ? "|$wrend|" : '-');
  }

  ##-- compute & assign: structural context: xcontext (undef -> '-')
  if ($do_xcontext) {
    $wcon = join('|', luniq(map {split(' ',$_->{xc})} @cs)) || '';
    $wnod->setAttribute($xcontext_attr, $wcon ? "|$wcon|" : '-');
  }

  ##-- compute & assign: xpath (undef -> '/..' (== empty node set))
  if ($do_xpath) {
    $wxpath = @cs ? $cs[0]{xp} : undef;
    $wxpath = '/..' if (!$wxpath); ##-- invalid xpath
    $wxpath =~ s|/c$||i;           ##-- prune final 'c'-element from //w xpath
    $wxpath =~ s|^/TEI(?:/text/?)?||; ##-- prune leading '/TEI/text' from //w xpath
    $wnod->setAttribute($xpath_attr, $wxpath);
  }

  ##-- compute & assign: page (undef -> -1; non-empty @cids only)
  if ($do_page) {
    $wpage = @cs ? $cs[0]{pb} : undef;
    $wpage = -1 if (!defined($wpage) || $wpage eq '');
    $wnod->setAttribute($page_attr, $wpage);
  }

  ##-- compute & assign: line (undef -> -1; non-empty @cids only)
  if ($do_line) {
    $wline = @cs ? $cs[0]{lb} : undef;
    $wline = -1 if (!defined($wline) || $wline eq '');
    $wnod->setAttribute($line_attr, $wline);
  }

  ##-- compute & assign: bbox (undef -> ''; non-empty @cids only) : TODO
  if ($do_bbox && @cs) {
    @wbboxes = bboxes(\@cs,$bbsingle);
    $wnod->setAttribute($bbox_attr, join('_', map {join('|',@$_)} @wbboxes));
  }

  ##-- record: claim //c indices
  vec($cn2wn, $_, $CN2WN_BITS) = $wi foreach (map {$_->{cn}} @cs);

  ##-- record: special attributes
  if ($w_is_formula) {
    push(@wfml,$wi);
  }
  elsif (!@cs) {
    ##-- @wnoc: //w node without //c id-list
    push(@wnoc,$wi);
  }
}


##======================================================================
## Subs: generic

## @uniq = luniq(@list)
my ($lu_tmp);
sub luniq {
  $lu_tmp=undef;
  return map {(defined($lu_tmp) && $lu_tmp eq $_ ? qw() : ($lu_tmp=$_))} sort @_;
}

## $min = lmin(@list)
my ($lmin_tmp);
sub lmin {
  $lmin_tmp=shift;
  foreach (grep {defined($_)} @_) {
    $lmin_tmp=$_ if (!defined($lmin_tmp) || $_ < $lmin_tmp);
  }
  return $lmin_tmp;
}

## $max = lmax(@list)
my ($lmax_tmp);
sub lmax {
  $lmax_tmp=shift;
  foreach (grep {defined($_)} @_) {
    $lmax_tmp=$_ if (!defined($lmax_tmp) || $_ > $lmax_tmp);
  }
  return $lmax_tmp;
}

## $avg = lavg(@list)
my ($lavg_tmp);
sub lavg {
  $lavg_tmp=undef;
  $lavg_tmp += $_ foreach (grep {defined($_)} @_);
  return undef if (!defined($lavg_tmp));
  return $lavg_tmp/scalar(@_);
}

## $median = lmedian(@list)
my (@lmed_tmp);
sub lmedian {
  @lmed_tmp = sort {$a<=>$b} grep {defined($_)} @_;
  return undef if (!@lmed_tmp);
  return scalar(@lmed_tmp)%2 == 0 ? (($lmed_tmp[@lmed_tmp/2-1]+$lmed_tmp[@lmed_tmp/2])/2) : @lmed_tmp[int(@lmed_tmp/2)];
}

## $stddev = lstddev(@list)
my ($lsd_ex,$lsd_ex2);
sub lstddev {
  return undef if (!defined($lsd_ex = lavg(@_)));
  $lsd_ex2 = lavg(map {$_**2} grep {defined($_)} @_);
  return sqrt($lsd_ex2 - $lsd_ex**2);
}


## @cids = clist($cids_str)
##  + expand compressed //c/@id lists, also accepts old-style space-separated id-lists
sub cidlist {
  map {
    (m/^(.*)c([0-9]+)\+([0-9]+)$/
     ? (map {$1.'c'.$_} ($2..($2+$3-1)))
     : $_)
  } (ref($_[0]) ? @{$_[0]} : split(' ',$_[0]));
}

## @cs = clist($cids_str)
## @cs = clist(\@cids)
##  + expand compressed //c/@id lists and unpack to hash
##  + also accepts old-style space-separated id-lists
sub clist {
  return
    (
     map {c_unpack($_)}
     @cn2packed[
		grep {defined($_)}
		@cid2cn{
		  map {
		    (m/^(.*)c([0-9]+)\+([0-9]+)$/
		     ? (map {$1.'c'.$_} ($2..($2+$3-1)))
		     : $_)
		  } split(' ',$_[0])
		}
	       ]
    );
}

## @clist = clist_byline($page,$line,$cn0)
sub clist_byline {
  my ($pb,$lb,$cn0) = @_;
  $cn0 = 0 if (!defined($cn0));

  my ($cn,$c);
  my (@cs);
  ##-- stupid linear scan: backwards until $cn <= FIRST_CHAR($page,$line)
  for ($cn=$cn0; $cn > 0 && $cn <= $#cn2packed; $cn--) {
    next if (!defined($c = c_unpack($cn2packed[$cn])));
    last if ($c->{pb} < $pb || ($c->{pb}==$pb && $c->{lb} <  $lb));
    next if ($c->{pb} > $pb || ($c->{pb}==$pb && $c->{lb} >= $lb));
  }

  ##-- stupid linear scan: forwards until $cn >= LAST_CHAR($page,$line), pushing onto @cs
  for ( ; $cn >= 0 && $cn <= $#cn2packed; $cn++) {
    next if (!defined($c = c_unpack($cn2packed[$cn])));
    push(@cs,$c) if ($c->{pb}==$pb && $c->{lb}==$lb);
    last if ($c->{pb} >$pb || ($c->{pb}==$pb && $c->{lb} > $lb));
  }

  return @cs;
}

## @bboxes = bboxes(\@cus)
## @bboxes = bboxes(\@cus,$single=0)
##  + gets list of word bounding boxes @bboxes=($bbox1,$bbox2,...)
##    for a "word" composed of the characters in //c/@id array-ref \@cids
##  + each bbox $bbox in @bboxes is of the form
##      $bbox=[$ulx,$uly,$lrx,$lry]
##    with $ulx<=$lrx, $uly<=$lry; where a coordinate of -1 indicates undefined
##  + if $single is true, at most a single bbox will be returned, otherwise
##    line- and column-breaks will be heuristically detected
sub bboxes {
  ($wcs,$bbsingle) = @_;
  @wbboxes = qw();
  return @wbboxes if (!$wcs || !@$wcs);
  @cbboxes = map {[@$_{qw(ulx uly lrx lry)}]} grep {$_->{pb} == $wcs->[0]{pb}} @$wcs;
  $wbbox   = undef;
  foreach $cbbox (@cbboxes) {
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
      ##-- extend current word bbox
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
  -page   , -nopage      # do/don't extract //w/@pb (page-break; default=do)
  -line   , -noline      # do/don't extract //w/@lb (line-break; default=do)
  -rend   , -norend      # do/don't extract //w/@xr (rendition; default=do)
  -xcon   , -noxcon      # do/don't extract //w/@xc (xml context; default=do)
  -xpath  , -noxpath     # do/don't extract //w/@xp (xpath; default=do)
  -bbox   , -nobbox      # do/don't extract //w/@bb (bbox; default=do)
  -cruft  , -nocruft     # do/don't extract //w/@u  (unicruft; default=do)
  -blanks , -noblanks    # do/don't keep 'ignorable' whitespace in T_XML_FILE file (default=don't)
  -keep-c , -nokeep-c    # do/don't keep existing //w/@c and //w/@cs attributes (default=don't)
  -keep-b , -nokeep-b    # do/don't keep existing //w/@b attributes (default=don't)
  -formula-text TEXT     # output text for //formula elements (default='' (no change))
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
