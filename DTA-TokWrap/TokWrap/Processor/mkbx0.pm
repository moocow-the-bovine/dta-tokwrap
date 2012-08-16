## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor::mkbx0.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA tokenizer wrappers: sxfile -> bx0doc

package DTA::TokWrap::Processor::mkbx0;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :libxml :libxslt :slurp :time);
use DTA::TokWrap::Processor;

use XML::LibXML;
use XML::LibXSLT;
use IO::File;

use Carp;
use strict;
use utf8;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor);

## $AUTOTUNE_MIN_C_PER_P
##  + minimum number of <c> per <p> for inclusion of sentence break hints for <p> elements
##    by autotune heuristics
##  + idea: accomodate OCR over-recognition of <p> elements, esp. for verse (e.g. busch_max_1865)
##  + empirical data:
##    - over all phase2 files                      : min=73.6, max=115892, median=564, avg=2242, sd=12541  [max here is verse basically without <p>]
##    - over all phase2 files with count(//p) >= 20: min=73.6, max=  2412, median=553, avg= 684, sd=  526  [well-coded verse outliers removed]
our $AUTOTUNE_MIN_C_PER_P = 200;

## $AUTOTUNE_MAX_LX_PER_L
##  + maximum fraction of tx lines matching /[[:lower:]][\-¬]$/
##    for application of $AUTOTUNE_MIN_C_PER_P autotune heuristic
##  + idea: differentiate verse from prose (verse --> low ratio, prosa --> high ratio),
##    since <p>-recognition errors are most likely for verse
##  + empirical data:
##    - over all phase2 files : min=0.0%, max=30.0%, median=22.0%, avg=16.50%, sd=9.15%
##    - over known verse files: min=0.0%, max= 0.8%, median= 0.3%, avg= 0.31%, sd=0.30%
##    - over known non-verse  : min=0.6%, max=29.9%, median=20.3%, avg=17.74%, sd=7.98%
our $AUTOTUNE_MAX_LX_PER_L = 0.01; ##-- 1.0%

## $AUTOTUNE_MAX_SP_PER_P
##  + maximum ratio of <sp> to <p> elements for inclusion of sentence break hints for
##    application of 
##  + overrides $AUTOTUNE_MIN_C_PER_P, $AUTOTUNE_MAX_LX_PER_L
##  + idea: for dramas, we can expect $AUTOTUNE_MIN_C_PER_P to be low, but <p>
##    recognition is more likely to be a help than a hindrance...
##  + empirical averages
##    - over phase2 known     dramas: min=81%, max=101%, median=93%, avg=92%, sd=6.1%
##    - over phase2 known non-dramas: min= 0%, max=  0%, median= 0%, avg= 0%, sd=0.0%
our $AUTOTUNE_MAX_SP_PER_P = 0.5; ##-- 50%

##==============================================================================
## Constructors etc.
##==============================================================================

## $mbx0 = CLASS_OR_OBJ->new(%args)
## %defaults = CLASS->defaults()
##  + %args, %defaults, %$mbx0:
##    (
##     ##-- Programs
##     rmns    => $path_to_xml_rm_namespaces, ##-- default: search
##     inplace => $bool,                      ##-- prefer in-place programs for search?
##     auto_prevnext => $bool,                ##-- if true (default), @prev|@next chains will be auto-sanitized
##     ##
##     ##-- Styleheet: insert-hints (<seg> elements and their children are handled implicitly)
##     hint_autotune  => $bool,               ##-- use empirical heuristics to hack hint xpaths? (default=true)
##     hint_sb_xpaths => \@xpaths,            ##-- add internal sentence-break hint (<s/>) for @xpath element open & close
##     hint_wb_xpaths => \@xpaths,            ##-- add internal word-break hint (<w/>) for @xpath element open & close
##     hint_lb_xpaths => \@xpaths,            ##-- add internal line-break hint (<lb/>), + external whitespace for @xpath element *close*
##     ##
##     hint_stylestr  => $stylestr,           ##-- xsl stylesheet string
##     hint_styleheet => $stylesheet,         ##-- compiled xsl stylesheet
##     ##
##     ##-- Stylesheet: mark-sortkeys (<seg> elements and their children are handled implicitly)
##     sortkey_attr => $attr,                 ##-- sort-key attribute (default: 'dta.tw.key')
##     sort_ignore_xpaths => \@xpaths,        ##-- ignore these xpaths
##     sort_addkey_xpaths => \@xpaths,        ##-- add new sort key for @xpaths
##     ##
##     sort_stylestr  => $stylestr,           ##-- xsl stylesheet string
##     sort_styleheet => $stylesheet,         ##-- compiled xsl stylesheet
##   )
sub defaults {
  my $that = shift;
  return (
	  ##-- inherited
	  $that->SUPER::defaults(),

	  ##-- programs
	  rmns   =>undef,
	  inplace=>1,
	  auto_prevnext => 1,

	  ##-- stylesheet: insert-hints
	  hint_autotune  => 1,
	  hint_sb_xpaths => [
			     ##-- title page
			     #qw(titlePage byline titlePart docAuthor docImprint pubPlace publisher docDate),
			     qw(titlePage),

			     ##-- main text: common
			     qw(p|div|text|front|back|body),

			     ##-- notes, tables, lists, etc.
			     qw(note|table|argument),
			     qw(figure),
			     'item[ref]',

			     ##-- drama-specific
			     ## + e.g. goethe_iphegenie, schiller_kabale, hauptman_sonnenaufgang
			     #qw(speaker sp stage castList castGroup castItem role roleDesc set),
			     #qw(speaker sp stage castList castGroup castItem role roleDesc set),
			     qw(castList|castGroup),
			     'castItem[not(parent::castGroup)]',

			     ##-- verse-specific
			     qw(lg),

			     ##-- non-sentential stuff
			     qw(ref|fw|list|item), ##-- ... be safe if tokenizing EVERYTHING (we should always EOS on head if we add a key for it!)
			     #qw(ref|fw), ##-- ... be extra-safe if tokenizing EVERYTHING
			    ],
	  hint_wb_xpaths => [
			     ##-- title page
			     qw(byline titlePart docAuthor docImprint pubPlace publisher docDate),

			     ##-- non-sentential stuff
			     qw(ref|fw), ##-- ... be safe if tokenizing EVERYTHING

			     ##-- citations & quotes (TODO: check real examples)
			     qw(cit|q|quote),

			     ##-- letters (TODO: check real examples)
			     qw(salute dateline opener closer signed),

			     ##-- notes, tables, lists, etc.
			     qw(row|cell),

			     ##-- drama-specific
			     ## + e.g. goethe_iphegenie, schiller_kabale, hauptman_sonnenaufgang
			     #qw(speaker sp stage castList castGroup castItem role roleDesc set),
			     qw(sp|speaker|stage|set),
			     qw(castGroup/castItem|role|roleDesc),

			     ##-- verse-specific
			     #qw(lg),

			     ##-- technical & mathematical
			     #qw(formula),
			    ],
	  hint_lb_xpaths => [
			     ##-- segments
			     'seg',

			     ##-- other things
			     #map { "$_\[not(parent::seg)\]" } qw(table note argument figure),
			    ],
	  hint_replace_xpaths => {
				  ##-- formulae
				  #'formula' => '<ws/><w/><c text="FORMEL"/><w/><ws/>',
				  'formula' => '<w/>',
				 },
	  hint_stylestr => undef,
	  hint_stylesheet => undef,

	  ##-- stylesheet: mark-sortkeys
	  sortkey_attr => 'dta.tw.key',
	  sort_ignore_xpaths => [
				 #qw(ref|fw|head), ##-- comment this out to tokenize EVERYTHING
				 qw(ref|fw),       ##--  ... tokenize <head> (e.g. chapter titles), but not headers, footers, or references (TOC)
				 qw(teiHeader),
				 #qw(formula),

				 ##-- choice stuff
				 'choice[./sic and ./corr]/sic',
				 'choice[./orig and ./reg]/orig',
				 'choice[./abbr and ./expan]/abbr',
				],
	  sort_addkey_xpaths => [
				 #'*[@next and not(@prev)]',
				 #(map {"$_\[not(parent::seg or ancestor::*\[\@next or \@prev\])\]"} qw(table note argument figure)),
				 ##--
				 (map {"$_\[not(parent::seg)\]"} qw(table note argument figure)),
				 qw(text|front|body|back),
				 qw(ref|fw|list|castList),
				 'head[not(parent::list or parent::castList)]',  ##-- extract these from running text
				],
	  sort_stylestr  => undef,
	  sort_styleheet => undef,
	 );
}

## $mbx0 = $mbx0->init()
sub init {
  my $mbx0 = shift;

  ##-- search for xml-rm-namespaces program
  if (!defined($mbx0->{rmns})) {
    $mbx0->{rmns} = path_prog('dtatw-rm-namespaces',
			    prepend=>($mbx0->{inplace} ? ['.','../src'] : undef),
			    warnsub=>sub {$mbx0->logconfess(@_)},
			   );
  }

  ##-- create stylesheet strings
  $mbx0->{hint_stylestr}   = $mbx0->hint_stylestr() if (!$mbx0->{hint_stylestr});
  $mbx0->{sort_stylestr}   = $mbx0->sort_stylestr() if (!$mbx0->{sort_stylestr});

  ##-- compile stylesheets
  #$mbx0->{hint_stylesheet} = xsl_stylesheet(string=>$mbx0->{hint_stylestr}) if (!$mbx0->{hint_stylesheet});
  #$mbx0->{sort_stylesheet} = xsl_stylesheet(string=>$mbx0->{sort_stylestr}) if (!$mbx0->{sort_stylesheet});

  return $mbx0;
}

##==============================================================================
## Methods: XSL stylesheets
##==============================================================================


##--------------------------------------------------------------
## Methods: XSL stylesheets: common

## $mbx0_or_undef = $mbx0->ensure_stylesheets()
sub ensure_stylesheets {
  my $mbx0 = shift;
  $mbx0->{hint_stylesheet} = xsl_stylesheet(string=>$mbx0->{hint_stylestr}) if (!$mbx0->{hint_stylesheet});
  $mbx0->{sort_stylesheet} = xsl_stylesheet(string=>$mbx0->{sort_stylestr}) if (!$mbx0->{sort_stylesheet});
  return $mbx0;
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: insert-hints
sub hint_stylestr {
  my $mbx0 = shift;
  return '<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" version="1.0" indent="no" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->
  <xsl:template match="/*" priority="100">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: implicit replacements -->'.join('',
						  map { "
  <xsl:template match=\"$_\">
    <ws/>
    <xsl:copy>
      <xsl:apply-templates select=\"@*\"/>
      $mbx0->{hint_replace_xpaths}{$_}
    </xsl:copy>
  </xsl:template>\n"
							 } keys %{$mbx0->{hint_replace_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: implicit sentence breaks -->'.join('',
						     map { "
  <xsl:template match=\"$_\">
    <ws/>
    <xsl:copy>
      <xsl:apply-templates select=\"@*\"/>
      <xsl:if test=\"not(./\@prev)\"><s/></xsl:if>
      <xsl:apply-templates select=\"*\"/>
      <xsl:if test=\"not(./\@next)\"><s/></xsl:if>
    </xsl:copy>
  </xsl:template>\n"
							 } @{$mbx0->{hint_sb_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: implicit token breaks -->'.join('',
						     map { "
  <xsl:template match=\"$_\">
    <ws/>
    <xsl:copy>
      <xsl:apply-templates select=\"@*\"/>
      <w/>
      <xsl:apply-templates select=\"*\"/>
      <w/>
    </xsl:copy>
  </xsl:template>\n"
							 } @{$mbx0->{hint_wb_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: implicit line breaks -->'.join('',
						     map { "
  <xsl:template match=\"$_\">
    <ws/>
    <xsl:copy>
      <xsl:apply-templates select=\"@*|*\"/>
      <lb/>
    </xsl:copy>
  </xsl:template>\n"
							 } @{$mbx0->{hint_lb_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: @prev|@next (priority=20) -->

  <xsl:template match="*[@next and not(@prev)]" priority="20">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
      <xsl:call-template name="chain.next">
	<xsl:with-param name="nextid" select="@next"/>
      </xsl:call-template>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*[@prev]" priority="20">
    <!-- ignore by default: these should get pulled in by named template "chain.next" -->
  </xsl:template>


  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: NAMED: chain.next -->

  <xsl:template name="chain.next">
    <xsl:param name="nextid" select="./@next"/>
    <xsl:if test="$nextid">
      <xsl:variable name="nextnod" select="id($nextid)"/>
      <ws/>
      <xsl:apply-templates select="$nextnod/*"/>
      <xsl:call-template name="chain.next">
	<xsl:with-param name="nextid" select="$nextnod/@next"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: seg (priority=10) -->
  <xsl:template match="seg[@part=\'I\']" priority="10">
    <ws/>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <s/>
      <xsl:apply-templates select="*"/>
      <lb/>
    </xsl:copy>
  </xsl:template>

  <!-- seg[@part=\'M\'] is handled by defaults -->

  <xsl:template match="seg[@part=\'F\']" priority="10">
    <ws/>
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
      <s/>
      <lb/>
    </xsl:copy>
  </xsl:template>

  <!-- avoid implicit breaks for explicitly segmented material -->
  <xsl:template match="seg/*|seg/@*" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: castGroup (priority=10) -->
  <xsl:template match="castGroup[count(./roleDesc)=1]" priority="10">
    <ws/>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <s/>
      <xsl:apply-templates select="*[name()!=\'roleDesc\']"/>
      <xsl:apply-templates select="roleDesc"/>
      <s/>
    </xsl:copy>
  </xsl:template>


  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: DEFAULT: copy -->
  <xsl:template match="*|@*" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
';
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: mark-sortkeys
sub sort_stylestr {
  my $mbx0 = shift;
  my $keyName = $mbx0->{sortkey_attr};
  return '<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" version="1.0" indent="no" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->

  <xsl:template match="/*">
    <xsl:copy>
      <xsl:attribute name="'.$keyName.'"><xsl:call-template name="generate-key"/></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: ignored material (priority=100) -->

  '.join("\n  ",
	 (map {"<xsl:template match=\"$_\" priority=\"100\"/>"} @{$mbx0->{sort_ignore_xpaths}})).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: seg (priority=10) -->

  <xsl:template match="seg[@part=\'I\']" priority="10">
    <xsl:copy>
      <xsl:attribute name="'.$keyName.'"><xsl:call-template name="generate-key"/></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="seg[@part=\'M\' or @part=\'F\']" priority="10">
    <xsl:variable name="keyNode" select="preceding::seg[@part=\'I\'][1]"/>
    <xsl:copy>
      <xsl:attribute name="'.$keyName.'"><xsl:call-template name="generate-key"><xsl:with-param name="node" select="$keyNode"/></xsl:call-template></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: material to adjoin (sort_addkey) -->
'.join('',
					       map {"
  <xsl:template match=\"$_\">
    <xsl:copy>
      <xsl:attribute name=\"$keyName\"><xsl:call-template name=\"generate-key\"/></xsl:attribute>
      <xsl:apply-templates select=\"*|@*\"/>
    </xsl:copy>
  </xsl:template>\n"
						  } @{$mbx0->{sort_addkey_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: DEFAULT: copy -->

  <xsl:template match="*|@*" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: NAMED: generate-key -->

  <xsl:template name="generate-key">
    <xsl:param name="node" select="."/>
    <xsl:value-of select="concat(name($node),\'.\',generate-id($node))"/>
  </xsl:template>

</xsl:stylesheet>
';
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: autotuning

## undef = $mbx0->hint_autotune(\$sxbuf,$txfilename)
##  + does hint autotuning
sub hint_autotune {
  my ($mbx0,$sxbufr,$txfile) = @_;

  ##-- buffer txfile
  my $txfh = IO::File->new("<$txfile")
    or $mbx0->logconfess("autotune($txfile): could not open txfile '$txfile'");
  $txfh->binmode(':utf8');
  my $txbufr = slurp_fh($txfh)
    or $mbx0->logconfess("autotune($txfile): could not slurp txfile '$txfile'");
  $txfh->close();

  ##-- cache original hint xpaths if required
  my $sb_xpaths = ($mbx0->{hint_sb_xpaths_pretune}
		   ? $mbx0->{hint_sb_xpaths_pretune}
		   : ($mbx0->{hint_sb_xpaths_pretune}=$mbx0->{hint_sb_xpaths}));

  ##-- count <p> and <p> elements
  my $np  = 0+($$sxbufr =~ s/<p\b/<p/sg);
  my $nsp = 0+($$sxbufr =~ s/<sp\b/<sp/sg);

  ##-- count characters (bytes) and lines
  my $nc  = length($$txbufr);           ##-- count number of logical utf8 characters in .tx buffer
  my $nl  = ($$txbufr =~ s/$//mg);      ##-- count number of newlines in .tx buffer
  my $nlx = 0+@{[$$txbufr =~ /[[:lower:]](?:\-|\x{ac})$/mg]}; ##-- estimate number of "line-broken" tokens

  ##-- compute hints
  my $c2p  = $nc/($np+1);
  my $lx2l = $nlx/$nl;
  my $sp2p = $nsp/($np+1);

  if ($c2p     <= $AUTOTUNE_MIN_C_PER_P
      && $lx2l <= $AUTOTUNE_MAX_LX_PER_L
      && $sp2p <= $AUTOTUNE_MAX_SP_PER_P)
    {
      $mbx0->{hint_sb_xpaths} = [grep {$_ !~ /^p$/} @$sb_xpaths];
    }
  else {
    $mbx0->{hint_sb_xpaths} = $sb_xpaths;
  }

  ##-- force stylesheet-regeneration
  $mbx0->{hint_stylestr}   = $mbx0->hint_stylestr();
  $mbx0->{hint_stylesheet} = xsl_stylesheet(string=>$mbx0->{hint_stylestr});
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: prev|next-chain sanitization

## $sxdoc = $mbx0->sanitize_chains($sxdoc)
##  + sanitizes @prev|@next chains in-place in $sxdoc (an XML::LibXML::Document) for $mbx0->{auto_prevnext} flag
sub sanitize_chains {
  my ($mbx0,$xmldoc) = @_;

  my ($nod,$nodid,$refid,$refnod);
  my $id=0;
  foreach $nod (@{$xmldoc->findnodes('//*[@prev or @next]')}) {
    $nodid = $nod->getAttribute('id') || $nod->getAttribute('xml:id') || $nod->getAttribute('xml_id');
    if (!defined($nodid)) {
      ##-- add @id
      $nodid = sprintf("dtatw.mkbx0.chain.%0.4x", ++$id);
      $mbx0->vlog('warn',"sanitize_chains(): auto-generating node-id $nodid for chain-node ", $nod->nodeName, " at line ", $nod->line_number);
      $nod->setAttribute('xml:id'=>$nodid);
    }
    if (defined($refid = $nod->getAttribute('prev'))) {
      ##-- sanitize @prev
      $refid  =~ s/^\#//;
      $refnod = $xmldoc->findnodes("id('$refid')")->[0];
      if (!$refnod) {
	$mbx0->vlog('warn',"sanitize_chains(): pruning dangling \@prev=$refid for chain node ", $nod->nodeName, " at line ", $nod->line_number);
	$nod->removeAttribute('prev');
      }
      elsif (!$refnod->getAttribute('next')) {
	$mbx0->vlog('warn',"sanitize_chains(): inserting \@next=$nodid for chain node ", $refnod->nodeName, " at line ", $refnod->line_number);
	$refnod->setAttribute('next'=>$nodid);
      }
    }
    if (defined($refid = $nod->getAttribute('next'))) {
      ##-- sanitize @next
      $refid  =~ s/^\#//;
      $refnod = $xmldoc->findnodes("id('$refid')")->[0];
      if (!$refnod) {
	$mbx0->vlog('warn',"sanitize_chains(): pruning dangling \@next=$refid for chain node ", $nod->nodeName, " at line ", $nod->line_number);
	$nod->removeAttribute('next');
      }
      elsif (!$refnod->getAttribute('prev')) {
	$mbx0->vlog('warn',"sanitize_chains(): inserting \@prev=$nodid for chain node ", $refnod->nodeName, " at line ", $refnod->line_number);
	$refnod->setAttribute('prev'=>$nodid);
      }
    }
  }

  return $xmldoc;
}


##--------------------------------------------------------------
## Methods: XSL stylesheets: debug

## undef = $mbx0->dump_string($str,$filename_or_fh)
sub dump_string {
  my ($mbx0,$str,$file) = @_;
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  $fh->print($str);
  $fh->close() if (!ref($file));
}

## undef = $mbx0->dump_hint_stylesheet($filename_or_fh)
sub dump_hint_stylesheet {
  $_[0]->dump_string($_[0]{hint_stylestr}, $_[1]);
}

## undef = $mbx0->dump_sort_stylesheet($filename_or_fh)
sub dump_sort_stylesheet {
  $_[0]->dump_string($_[0]{sort_stylestr}, $_[1]);
}


##==============================================================================
## Methods: mkbx0 (apply stylesheets)
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->mkbx0($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    sxfile  => $sxfile,  ##-- (input) structure index filename
##    txfile  => $txfile,  ##-- (input) raw text index filename [only for autotune]
##    bx0doc  => $bx0doc,  ##-- (output) preliminary block-index data (XML::LibXML::Document)
##    mkbx0_stamp0 => $f,  ##-- (output) timestamp of operation begin
##    mkbx0_stamp  => $f,  ##-- (output) timestamp of operation end
##    bx0doc_stamp => $f,  ##-- (output) timestamp of operation end
sub mkbx0 {
  my ($mbx0,$doc) = @_;

  ##-- log, stamp
  $mbx0->vlog($mbx0->{traceLevel},"mkbx0($doc->{xmlbase})");
  $doc->{mkbx0_stamp0} = timestamp();

  ##-- sanity check(s): basic
  $mbx0 = $mbx0->new() if (!ref($mbx0));
  $mbx0->logconfess("mkbx0($doc->{xmlbase}): no dtatw-rm-namespaces program")
    if (!$mbx0->{rmns});
  $mbx0->logconfess("mbx0($doc->{xmlbase}): no .sx file defined")
    if (!$doc->{sxfile});
  $mbx0->logconfess("mbx0($doc->{xmlbase}): .sx file unreadable: $!")
    if (!-r $doc->{sxfile});

  ##-- buffer sx file
  my $cmdfh = IO::File->new("'$mbx0->{rmns}' '$doc->{sxfile}'|")
    or $mbx0->logconfess("mkbx0($doc->{xmlbase}): open failed for pipe from '$mbx0->{rmns}': $!");
  my $sxbuf = '';
  slurp_fh($cmdfh, \$sxbuf);
  $cmdfh->close();

  ##-- parse sx buffer
  my $xmlparser = libxml_parser(keep_blanks=>0);
  my $sxdoc = $xmlparser->parse_string($sxbuf)
    or $mbx0->logconfess("mkbx0($doc->{xmlbase}): could not parse namespace-hacked .sx document '$doc->{sxfile}': $!");

  ##-- autotune?
  if ($mbx0->{hint_autotune}) {
    ##-- sanity checks: .tx
    $mbx0->logconfess("mbx0($doc->{xmlbase}): no .tx file defined")
      if (!$doc->{txfile});
    $mbx0->logconfess("mbx0($doc->{xmlbase}): .tx file unreadable: $!")
      if (!-r $doc->{txfile});

    $mbx0->hint_autotune(\$sxbuf,$doc->{txfile});
  }

  ##-- auto-sanitize (prev|next)-chains
  $mbx0->sanitize_chains($sxdoc) if ($mbx0->{auto_prevnext});

  ##-- apply XSL stylesheets
  $mbx0->logconfess("mkbx0($doc->{xmlbase}): could not compile XSL stylesheets")
    if (!$mbx0->ensure_stylesheets);
  $sxdoc = $mbx0->{hint_stylesheet}->transform($sxdoc)
    or $mbx0->logconfess("mkbx0($doc->{xmlbase}): could not apply hint stylesheet to .sx document '$doc->{sxfile}': $!");
  $sxdoc = $mbx0->{sort_stylesheet}->transform($sxdoc)
    or $mbx0->logconfess("mkbx0($doc->{xmlfile}): could not apply sortkey stylesheet to .sx document '$doc->{sxfile}': $!");

  ##-- adjust $doc
  $doc->{bx0doc} = $sxdoc;
  $doc->{mkbx0_stamp} = $doc->{bx0doc_stamp} = timestamp(); ##-- stamp
  return $doc;
}

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, and edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Processor::mkbx0 - DTA tokenizer wrappers: sxfile -> bx0doc

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Processor::mkbx0;
 
 $mbx0 = DTA::TokWrap::Processor::mkbx0->new(%opts);
 $doc_or_undef = $mbx0->mkbx0($doc);
 
 ##-- debugging
 $mbx0_or_undef = $mbx0->ensure_stylesheets();
 $mbx0->dump_hint_stylesheet($filename_or_fh);
 $mbx0->dump_sort_stylesheet($filename_or_fh);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::TokWrap::Processor::mkindex provides an object-oriented
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor> wrapper
for
hint insertion and serialization sort-key generation
on a text-free "structure index" (.sx) XML file.

Most users should use the high-level
L<DTA::TokWrap|DTA::TokWrap> wrapper class
instead of using this module directly.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkbx0: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Processor::mkbx0
inherits from
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkbx0: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $mbx0 = $CLASS_OR_OBJ->new(%opts)

Constructor.

%opts, %$mbx0:

 ##-- Programs
 rmns    => $path_to_xml_rm_namespaces, ##-- default: search
 inplace => $bool,                      ##-- prefer in-place programs for search?
 ##
 ##-- Styleheet: insert-hints (<seg> elements and their children are handled implicitly)
 hint_sb_xpaths => \@xpaths,            ##-- add sentence-break hint (<s/>) for @xpath element open & close
 hint_wb_xpaths => \@xpaths,            ##-- ad word-break hint (<w/>) for @xpath element open & close
 ##
 hint_stylestr  => $stylestr,           ##-- xsl stylesheet string
 hint_styleheet => $stylesheet,         ##-- compiled xsl stylesheet
 ##
 ##-- Stylesheet: mark-sortkeys (<seg> elements and their children are handled implicitly)
 sortkey_attr => $attr,                 ##-- sort-key attribute (default: 'dta.tw.key')
 sort_ignore_xpaths => \@xpaths,        ##-- ignore these xpaths
 sort_addkey_xpaths => \@xpaths,        ##-- add new sort key for @xpaths
 ##
 sort_stylestr  => $stylestr,           ##-- xsl stylesheet string
 sort_styleheet => $stylesheet,         ##-- compiled xsl stylesheet

=item defaults

 %defaults = CLASS->defaults();

Static class-dependent defaults.

=item init

 $mbx0 = $mbx0->init();

Dynamic object-dependent defaults.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkbx0: Methods: XSL stylesheets
=pod

=head2 Methods: XSL stylesheets

=over 4

=item ensure_stylesheets

 $mbx0_or_undef = $mbx0->ensure_stylesheets();

Ensures that required XSL stylesheets have been compiled.

=item hint_stylestr

 $xsl_str = $mbx0->hint_stylestr();

Returns XSL stylesheet string for the 'insert-hints' transformation,
which is responsible for inserting sentence- and token-break hints
into the input *.sx document.

=item sort_stylestr

 $xsl_str = $mbx0->sort_stylestr();

Returns XSL stylesheet string for the 'generate-sort-keys' transformation,
which is responsible for inserting top-level serialization-segment keys
into the input *.sx document.

=item dump_hint_stylesheet

 $mbx0->dump_hint_stylesheet($filename_or_fh);

Dumps the generated 'insert-hints' stylesheet to $filename_or_fh.

=item dump_sort_stylesheet

 $mbx0->dump_sort_stylesheet($filename_or_fh);

Dumps the generated 'generate-sortkeys' stylesheet to $filename_or_fh.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkbx0: Methods: mkbx0 (apply stylesheets)
=pod

=head2 Methods: top-level

=over 4

=item mkbx0

 $doc_or_undef = $CLASS_OR_OBJECT->mkbx0($doc);

Applies the XSL pipeline for hint insertion and
sort-key generation to the "structure index" (*.sx)
document of the
L<DTA::TokWrap::Document|DTA::TokWrap::Document> object
$doc.

Relevant %$doc keys:

 sxfile  => $sxfile,  ##-- (input) structure index filename
 bx0doc  => $bx0doc,  ##-- (output) preliminary block-index data (XML::LibXML::Document)
 ##
 mkbx0_stamp0 => $f,  ##-- (output) timestamp of operation begin
 mkbx0_stamp  => $f,  ##-- (output) timestamp of operation end
 bx0doc_stamp => $f,  ##-- (output) timestamp of operation end

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## See Also
##======================================================================

=pod

=head1 SEE ALSO

L<DTA::TokWrap::Intro(3pm)|DTA::TokWrap::Intro>,
L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
...

=cut

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
