<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output
    method="xml"
    version="1.0"
    indent="no"
    encoding="UTF-8"
    />

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- parameters -->
  <!--<xsl:param name="path" select="//text/w"/>-->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <!--<xsl:strip-space elements="text div p seg note table row cell loc lb pb"/>-->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->
  <xsl:template match="/">
    <xsl:apply-templates select="*|@*"/>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Main Text (MAIN) -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: MAIN: ignored stuff: see mark-sortkeys.xsl -->
  <!--<xsl:template match="ref|fw" priority="100"/>-->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: MAIN: implicit sentence breaks -->
  <xsl:template match="div|p|text|front|back|body">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <s/>
      <xsl:apply-templates select="*"/>
      <s/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: MAIN: implicit token breaks -->
  <xsl:template match="cit|q|quote|head">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <w/>
      <xsl:apply-templates select="*"/>
      <w/>
    </xsl:copy>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Special Cases (OTHER) -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: seg (priority=10) -->
  <xsl:template match="seg[@part='I']" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <s/>
      <xsl:apply-templates select="*"/>
    </xsl:copy>
  </xsl:template>

  <!-- seg[@part='M'] is handled by defaults -->

  <xsl:template match="seg[@part='F']" priority="10">
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
  <!-- templates: OTHER: note -->
  <xsl:template match="note">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <s/>
      <xsl:apply-templates select="*"/>
      <s/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: table -->
  <xsl:template match="table">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <s/>
      <xsl:apply-templates select="*"/>
      <s/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="row|cell">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <w/>
      <xsl:apply-templates select="*"/>
      <w/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: list, item -->
  <xsl:template match="list|item">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <w/>
      <xsl:apply-templates select="*"/>
      <w/>
    </xsl:copy>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- defaults -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- defaults: copy -->
  <xsl:template match="*|@*" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
