<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output
    method="xml"
    version="1.0"
    indent="yes"
    encoding="UTF-8"
    />

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- parameters -->
  <!--<xsl:param name="path" select="//text/w"/>-->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <xsl:strip-space elements="text div p seg note table row cell"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->
  <xsl:template match="/">
    <dta.tw.serialized>
      <div type="dta.tw.main">
	<xsl:apply-templates select="//*[child::loc and not(ancestor-or-self::seg or ancestor-or-self::note or ancestor-or-self::table)]"/>
      </div>
      <s/>
      <!--
      <div type="dta.tw.post">
	<xsl:apply-templates select="//seg"/>
	<xsl:apply-templates select="//note[not(ancestor::seg)]"/>
	<xsl:apply-templates select="//table[not(ancestor::seg)]"/>
      </div>-->
    </dta.tw.serialized>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- templates: tables -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- tables: table -->
  <xsl:template match="table[not(ancestor::seg)]">
    <s/>
    <xsl:apply-templates select="*"/>
    <s/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- tables: rows, cells -->
  <xsl:template match="row[not(ancestor::seg)] | cell[not(ancestor::seg)]">
    <w/>
    <xsl:apply-templates select="*"/>
    <w/>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- template: note, no seg -->
  <xsl:template match="note[not(ancestor::seg)]">
    <s/>
    <xsl:apply-templates select="*"/>
    <s/>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- seg -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- seg: initial -->
  <xsl:template match="seg[@part='I']">
    <s/>
    <xsl:apply-templates select="*"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- seg: final -->
  <xsl:template match="seg[@part='F']">
    <xsl:apply-templates select="*"/>
    <s/>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- loc, lb, pb: copy -->
  <xsl:template match="loc|lb|pb">
    <xsl:copy-of select="."/>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- default: just recurse -->
  <xsl:template match="*|@*|text()|processing-instruction()|comment()" priority="-1">
    <xsl:apply-templates select="*"/>
  </xsl:template>

</xsl:stylesheet>
