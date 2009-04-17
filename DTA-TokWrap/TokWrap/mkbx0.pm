## -*- Mode: CPerl -*-

## File: DTA::TokWrap::mkbx0
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: bx0 (preliminary block index)

package DTA::TokWrap::mkbx0;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :libxml :libxslt);
use DTA::TokWrap::Document;

use XML::LibXML;
use XML::LibXSLT;

use IO::File;

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Base);

##==============================================================================
## Constructors etc.
##==============================================================================

## $mb = CLASS_OR_OBJ->new(%args)
##  + %args:
##    ##-- Programs
##    rmns    => $path_to_xml_rm_namespaces, ##-- default: search
##    inplace => $bool,                      ##-- prefer in-place programs for search?
##    ##
##    ##-- Styleheet: insert-hints (<seg> elements and their children are handled implicitly)
##    hint_sb_xpaths => \@xpaths,            ##-- sentence-break hint for @xpath element open & close
##    hint_wb_xpaths => \@xpaths,            ##-- word-break hint for @xpath element open & close
##    ##
##    hint_stylestr  => $stylestr,           ##-- xsl stylesheet string
##    hint_styleheet => $stylesheet,         ##-- compiled xsl stylesheet
##    ##
##    ##-- Stylesheet: mark-sortkeys (<seg> elements and their children are handled implicitly)
##    sortkey_attr => $attr,                 ##-- sort-key attribute (default: 'dta.tw.key')
##    sort_ignore_xpaths => \@xpaths,        ##-- ignore these xpaths
##    sort_addkey_xpaths => \@xpaths,        ##-- add new sort key for @xpaths
##    ##
##    sort_stylestr  => $stylestr,           ##-- xsl stylesheet string
##    sort_styleheet => $stylesheet,         ##-- compiled xsl stylesheet

## %defaults = CLASS->defaults()
sub defaults {
  my $that = shift;
  return (
	  ##-- inherited
	  $that->SUPER::defaults(),

	  ##-- programs
	  rmns   =>undef,
	  inplace=>1,

	  ##-- stylesheet: insert-hings
	  hint_sb_xpaths => [
			     qw(div|p|text|front|back|body),
			     qw(note|table)
			    ],
	  hint_wb_xpaths => [
			     qw(cit|q|quote|head),
			     qw(row|cell),
			     qw(list),
			     qw(item),
			    ],
	  hint_stylestr => undef,
	  hint_stylesheet => undef,

	  ##-- stylesheet: mark-sortkeys
	  sortkey_attr => 'dta.tw.key',
	  sort_ignore_xpaths => [
				 qw(ref|fw|head)
				],
	  sort_addkey_xpaths => [
				 (map {"$_\[not(parent::seg)\]"} qw(table note)),
				],
	  sort_stylestr  => undef,
	  sort_styleheet => undef,
	 );
}

## $mb = $mb->init()
sub init {
  my $mb = shift;

  ##-- search for xml-rm-namespaces program
  if (!defined($mb->{rmns})) {
    $mb->{rmns} = path_prog('xml-rm-namespaces',
			    prepend=>($mb->{inplace} ? ['.','../src'] : undef),
			    warnsub=>\&croak,
			   );
  }

  ##-- create stylesheet strings
  $mb->{hint_stylestr}   = $mb->hint_stylestr() if (!$mb->{hint_stylestr});
  $mb->{sort_stylestr}   = $mb->sort_stylestr() if (!$mb->{sort_stylestr});

  ##-- compile stylesheets
  #$mb->{hint_stylesheet} = xsl_stylesheet(string=>$mb->{hint_stylestr}) if (!$mb->{hint_stylesheet});
  #$mb->{sort_stylesheet} = xsl_stylesheet(string=>$mb->{sort_stylestr}) if (!$mb->{sort_stylesheet});

  return $mb;
}

##==============================================================================
## Methods: XSL stylesheets
##==============================================================================

##--------------------------------------------------------------
## Methods: XSL stylesheets: common

## $mb_or_undef = $mb->ensure_stylesheets()
sub ensure_stylesheets {
  my $mb = shift;
  $mb->{hint_stylesheet} = xsl_stylesheet(string=>$mb->{hint_stylestr}) if (!$mb->{hint_stylesheet});
  $mb->{sort_stylesheet} = xsl_stylesheet(string=>$mb->{sort_stylestr}) if (!$mb->{sort_stylesheet});
  return $mb;
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: insert-hints
sub hint_stylestr {
  my $mb = shift;
  return '<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" version="1.0" indent="no" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->
  <xsl:template match="/">
    <xsl:apply-templates select="*|@*"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: implicit sentence breaks -->'.join('',
						     map { "
  <xsl:template match=\"$_\">
    <xsl:copy>
      <xsl:apply-templates select=\"@*\"/>
      <s/>
      <xsl:apply-templates select=\"*\"/>
      <s/>
    </xsl:copy>
  </xsl:template>\n"
							 } @{$mb->{hint_sb_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: implicit token breaks -->'.join('',
						     map { "
  <xsl:template match=\"$_\">
    <xsl:copy>
      <xsl:apply-templates select=\"@*\"/>
      <w/>
      <xsl:apply-templates select=\"*\"/>
      <w/>
    </xsl:copy>
  </xsl:template>\n"
							 } @{$mb->{hint_wb_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: seg (priority=10) -->
  <xsl:template match="seg[@part=\'I\']" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <s/>
      <xsl:apply-templates select="*"/>
    </xsl:copy>
  </xsl:template>

  <!-- seg[@part=\'M\'] is handled by defaults -->

  <xsl:template match="seg[@part=\'F\']" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
      <s/>
    </xsl:copy>
  </xsl:template>

  <!-- avoid implicit breaks for explicitly segmented material -->
  <xsl:template match="seg/*|seg/@*" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
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
  my $mb = shift;
  my $keyName = $mb->{sortkey_attr};
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
	 (map {"<xsl:template match=\"$_\" priority=\"100\"/>"} @{$mb->{sort_ignore_xpaths}})).'

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
						  } @{$mb->{sort_addkey_xpaths}}).'

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
## Methods: XSL stylesheets: debug

## undef = $mb->dump_string($str,$filename_or_fh)
sub dump_string {
  my ($mb,$str,$file) = @_;
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  $fh->print($str);
  $fh->close() if (!ref($file));
}

## undef = $mb->dump_hint_stylesheet($filename_or_fh)
sub dump_hint_stylesheet {
  $_[0]->dump_string($_[0]{hint_stylestr}, $_[1]);
}

## undef = $mb->dump_sort_stylesheet($filename_or_fh)
sub dump_sort_stylesheet {
  $_[0]->dump_string($_[0]{sort_stylestr}, $_[1]);
}

##==============================================================================
## Methods: Run
##==============================================================================

## $doc_or_undef = $mi->mkbx0($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    sxfile  => $sxfile,  ##-- (input) structure index filename
##    bx0doc  => $bx0doc,  ##-- (output) preliminary block-index data (XML::LibXML::Document)
sub mkbx0 {
  my ($mb,$doc) = @_;

  ##-- sanity check(s)
  confess(ref($mb), "::mkbx0(): no xml-rm-namespaces program") if (!$mb->{rmns});
  $mb->ensure_stylesheets()
    or confess(ref($mb), "::mkbx0(): could not compile XSL stylesheets");
  confess(ref($mb), "::mkbx0(): no .sx file defined for document '$doc->{xmlfile}'")
    if (!$doc->{sxfile});
  confess(ref($mb), "::mkbx0(): .sx file '$doc->{sxfile}' not readable")
    if (!-r $doc->{sxfile});

  ##-- run command, buffer output to string
  my $cmdfh = IO::File->new("'$mb->{rmns}' '$doc->{sxfile}'|")
    or confess(ref($mb),"::mkbx0(): open failed for pipe from '$mb->{rmns}' '$doc->{sxfile}': $!");
  my $sxbuf = join('', $cmdfh->getlines);
  $cmdfh->close();

  ##-- parse buffer
  my $xmlparser = libxml_parser(keep_blanks=>0);
  my $sxdoc = $xmlparser->parse_string($sxbuf)
    or confess(ref($mb), "::mkbx0(): could not parse namespace-hacked .sx document '$doc->{sxfile}': $!");

  ##-- apply XSL stylesheets
  $sxdoc = $mb->{hint_stylesheet}->transform($sxdoc)
    or confess(ref($mb), "::mkbx0(): could not apply hint stylesheet to .sx document '$doc->{sxfile}': $!");
  $sxdoc = $mb->{sort_stylesheet}->transform($sxdoc)
    or confess(ref($mb), "::mkbx0(): could not apply sortkey stylesheet to .sx document '$doc->{sxfile}': $!");

  ##-- adjust $doc
  $doc->{bx0doc} = $sxdoc;

  return $doc;
}


1; ##-- be happy

