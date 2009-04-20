## -*- Mode: CPerl -*-

## File: DTA::TokWrap::standoff.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: t.xml -> (s.xml, w.xml, a.xml)

package DTA::TokWrap::standoff;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :libxml :libxslt :slurp);

use XML::LibXML;
use XML::LibXSLT;
use IO::File;
use File::Basename qw(basename);

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Base);

##==============================================================================
## Constructors etc.
##==============================================================================

## $so = CLASS_OR_OBJ->new(%args)
## %defaults = CLASS->defaults()
##  + %args, %defaults, %$so:
##    (
##     ##
##     ##-- Stylesheet: tx2sx (t.xml -> s.xml)
##     t2s_stylestr  => $stylestr,           ##-- xsl stylesheet string
##     t2s_styleheet => $stylesheet,         ##-- compiled xsl stylesheet
##     ##
##     ##-- Styleheet: tx2wx (t.xml -> w.xml)
##     t2w_stylestr  => $stylestr,           ##-- xsl stylesheet string
##     t2w_styleheet => $stylesheet,         ##-- compiled xsl stylesheet
##     ##
##     ##-- Styleheet: tx2wx (t.xml -> a.xml)
##     t2a_stylestr  => $stylestr,           ##-- xsl stylesheet string
##     t2a_styleheet => $stylesheet,         ##-- compiled xsl stylesheet
##   )
sub defaults {
  my $that = shift;
  return (
	  ##-- inherited
	  $that->SUPER::defaults(),
	 );
}

## $so = $so->init()
sub init {
  my $so = shift;

  ##-- create stylesheet strings
  $so->{t2s_stylestr}   = $so->t2s_stylestr() if (!$so->{t2a_stylestr});
  $so->{t2w_stylestr}   = $so->t2w_stylestr() if (!$so->{t2w_stylestr});
  $so->{t2a_stylestr}   = $so->t2a_stylestr() if (!$so->{t2a_stylestr});

  ##-- compile stylesheets
  #$so->{t2s_stylesheet} = xsl_stylesheet(string=>$so->{t2s_stylestr}) if (!$so->{t2s_stylesheet});
  #$so->{t2w_stylesheet} = xsl_stylesheet(string=>$so->{t2w_stylestr}) if (!$so->{t2w_stylesheet});
  #$so->{t2a_stylesheet} = xsl_stylesheet(string=>$so->{t2a_stylestr}) if (!$so->{t2a_stylesheet});

  return $so;
}

##==============================================================================
## Methods: XSL stylesheets
##==============================================================================

##--------------------------------------------------------------
## Methods: XSL stylesheets: common

## $so_or_undef = $so->ensure_stylesheets()
sub ensure_stylesheets {
  my $so = shift;
  $so->{t2s_stylesheet} = xsl_stylesheet(string=>$so->{t2s_stylestr}) if (!$so->{t2s_stylesheet});
  $so->{t2w_stylesheet} = xsl_stylesheet(string=>$so->{t2w_stylestr}) if (!$so->{t2w_stylesheet});
  $so->{t2a_stylesheet} = xsl_stylesheet(string=>$so->{t2a_stylestr}) if (!$so->{t2a_stylesheet});
  return $so;
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: t2s: t.xml -> s.xml
sub t2s_stylestr {
  my $so = shift;
  return '<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" version="1.0" indent="no" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- parameters -->
  <xsl:param name="xmlbase" select="/*/@xml:base"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <xsl:strip-space elements="sentences s w a"/>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Mode: main -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: root: traverse -->
  <xsl:template match="/*">
    <xsl:element name="sentences">
      <xsl:attribute name="xml:base"><xsl:value-of select="$xmlbase"/></xsl:attribute>
      <xsl:apply-templates select="*"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: s -->
  <xsl:template match="s">
    <xsl:element name="s">
      <xsl:copy-of select="./@xml:id"/>
      <xsl:apply-templates select="*"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: w -->
  <xsl:template match="w">
    <xsl:element name="w">
      <xsl:attribute name="ref">#<xsl:value-of select="./@xml:id"/></xsl:attribute>
      <xsl:apply-templates select="*"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: default: just recurse -->
  <xsl:template match="*|@*|text()|processing-instruction()|comment()" priority="-1">
    <xsl:apply-templates select="*|@*"/>
  </xsl:template>

</xsl:stylesheet>
';
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: t2w: t.xml -> w.xml
sub t2w_stylestr {
  my $so = shift;
  return '<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" version="1.0" indent="no" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- parameters -->
  <xsl:param name="xmlbase" select="/*/@xml:base"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <xsl:strip-space elements="sentences s w a"/>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Mode: main -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: root: traverse -->
  <xsl:template match="/*">
    <xsl:element name="tokens">
      <xsl:attribute name="xml:base"><xsl:value-of select="$xmlbase"/></xsl:attribute>
      <xsl:apply-templates select="*"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: w -->
  <xsl:template match="w">
    <xsl:element name="w">
      <xsl:copy-of select="@xml:id"/>
      <xsl:copy-of select="@t"/>
      <xsl:call-template name="w-expand-c"/>
      <xsl:apply-templates select="*"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: default: just recurse -->
  <xsl:template match="*|@*|text()|processing-instruction()|comment()" priority="-1">
    <xsl:apply-templates select="*"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- named: w-ref -->
  <xsl:template name="w-expand-c">
    <xsl:param name="cs" select="concat(@c,\' \')"/>
    <xsl:if test="$cs != \'\'">
      <xsl:element name="c">
	<xsl:attribute name="ref">#<xsl:value-of select="substring-before($cs,\' \')"/></xsl:attribute>
      </xsl:element>
      <xsl:call-template name="w-expand-c">
	<xsl:with-param name="cs" select="substring-after($cs,\' \')"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
';
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: t2w: t.xml -> a.xml
sub t2a_stylestr {
  my $so = shift;
  return '<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" version="1.0" indent="no" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- parameters -->
  <xsl:param name="xmlbase" select="/*/@xml:base"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <xsl:strip-space elements="sentences s w a"/>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Mode: main -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: root: traverse -->
  <xsl:template match="/*">
    <xsl:element name="tokens">
      <xsl:attribute name="xml:base"><xsl:value-of select="$xmlbase"/></xsl:attribute>
      <xsl:apply-templates select="*"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: w -->
  <xsl:template match="w">
    <xsl:element name="w">
      <xsl:attribute name="ref">#<xsl:value-of select="@xml:id"/></xsl:attribute>
      <!--<xsl:copy-of select="@t"/>-->  <!-- DEBUG: copy text -->
      <xsl:apply-templates select="*"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: w/a -->
  <xsl:template match="w/a">
    <xsl:element name="a">
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates select="*|text()"/>
    </xsl:element>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: w/a/text() -->
  <xsl:template match="w/a/text()">
    <xsl:copy-of select="."/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: default: just recurse -->
  <xsl:template match="*|@*|text()|processing-instruction()|comment()" priority="-1">
    <xsl:apply-templates select="*"/>
  </xsl:template>

</xsl:stylesheet>
';
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: debug

## undef = $so->dump_string($str,$filename_or_fh)
sub dump_string {
  my ($so,$str,$file) = @_;
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  $fh->print($str);
  $fh->close() if (!ref($file));
}

## undef = $so->dump_t2s_stylesheet($filename_or_fh)
sub dump_t2s_stylesheet {
  $_[0]->dump_string($_[0]{t2s_stylestr}, $_[1]);
}

## undef = $so->dump_t2w_stylesheet($filename_or_fh)
sub dump_t2w_stylesheet {
  $_[0]->dump_string($_[0]{t2w_stylestr}, $_[1]);
}

## undef = $so->dump_t2a_stylesheet($filename_or_fh)
sub dump_t2a_stylesheet {
  $_[0]->dump_string($_[0]{t2a_stylestr}, $_[1]);
}

##==============================================================================
## Methods: mkbx0 (apply stylesheets)
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->standoff($doc)
##  + wrapper for sosxml(), sowxml(), soaxml()
sub standoff {
  my ($so,$doc) = @_;
  $so = $so->new if (!ref($so));
  return $so->sosxml($doc) && $so->sowxml($doc) && $so->soaxml($doc);
}

## $doc_or_undef = $CLASS_OR_OBJECT->sosxml($doc)
## + $doc is a DTA::TokWrap::Document object
## + (re-)creates s.xml standoff document $doc->{sosdoc} from $doc->{xtokdoc}
## + %$doc keys:
##    xtokdoc  => $xtokdoc,  ##-- (input) XML-ified tokenizer output data, as XML::LibXML::Document
##    xtokdata => $xtokdata, ##-- (input) fallback: string source for $xtokdoc
##    sosdoc   => $sosdoc,   ##-- (output) standoff sentence data, refers to 'sowdoc'
sub sosxml {
  my ($so,$doc) = @_;

  ##-- sanity check(s)
  $so = $so->new() if (!ref($so));
  $so->ensure_stylesheets()
    or confess(ref($so), "::sosxml($doc->{xmlfile}): could not compile XSL stylesheet(s)");
  my $xtdoc = $doc->xtokDoc()
    or confess(ref($so), "::sosxml($doc->{xmlfile}: could not create/parse .t.xml document: $!");

  ##-- apply XSL stylesheet
  $doc->{sosdoc} = $so->{t2s_stylesheet}->transform($xtdoc,
						    xmlbase=>("'".basename($doc->{sowfile})."'"),
						   )
    or confess(ref($so), "::sosxml($doc->{xmlfile}): could not apply t2s_stylesheet: $!");

  return $doc;
}

## $doc_or_undef = $CLASS_OR_OBJECT->sowxml($doc)
## + $doc is a DTA::TokWrap::Document object
## + (re-)creates w.xml standoff document $doc->{sowdoc} from $doc->{xtokdoc}
## + %$doc keys:
##    xtokdoc  => $xtokdoc,  ##-- (input) XML-ified tokenizer output data, as XML::LibXML::Document
##    xtokdata => $xtokdata, ##-- (input) fallback: string source for $xtokdoc
##    sowdoc   => $sowdoc,   ##-- (output) standoff token data, refers to 'sowdoc'
sub sowxml {
  my ($so,$doc) = @_;

  ##-- sanity check(s)
  $so = $so->new() if (!ref($so));
  $so->ensure_stylesheets()
    or confess(ref($so), "::sowxml($doc->{xmlfile}): could not compile XSL stylesheet(s)");
  my $xtdoc = $doc->xtokDoc()
    or confess(ref($so), "::sowxml($doc->{xmlfile}: could not create/parse .t.xml document: $!");

  ##-- apply XSL stylesheet
  $doc->{sowdoc} = $so->{t2w_stylesheet}->transform($xtdoc,
						   xmlbase=>("'".$doc->{xmlbase}."'"),
						  )
    or confess(ref($so), "::sosxml($doc->{xmlfile}): could not apply t2w_stylesheet: $!");

  return $doc;
}

## $doc_or_undef = $CLASS_OR_OBJECT->soaxml($doc)
## + $doc is a DTA::TokWrap::Document object
## + (re-)creates a.xml standoff document $doc->{soadoc} from $doc->{xtokdoc}
## + %$doc keys:
##    xtokdoc  => $xtokdoc,  ##-- (input) XML-ified tokenizer output data, as XML::LibXML::Document
##    xtokdata => $xtokdata, ##-- (input) fallback: string source for $xtokdoc
##    soadoc   => $soadoc,   ##-- (output) standoff token-analysis data, refers to 'sowdoc'
sub soaxml {
  my ($so,$doc) = @_;

  ##-- sanity check(s)
  $so = $so->new() if (!ref($so));
  $so->ensure_stylesheets()
    or confess(ref($so), "::soaxml($doc->{xmlfile}): could not compile XSL stylesheet(s)");
  my $xtdoc = $doc->xtokDoc()
    or confess(ref($so), "::soaxml($doc->{xmlfile}: could not create/parse .t.xml document: $!");

  ##-- apply XSL stylesheet
  $doc->{soadoc} = $so->{t2a_stylesheet}->transform($xtdoc,
						   xmlbase=>("'".basename($doc->{sowfile})."'"),
						  )
    or confess(ref($so), "::soaxml($doc->{xmlfile}): could not apply t2a_stylesheet: $!");

  return $doc;
}

1; ##-- be happy

