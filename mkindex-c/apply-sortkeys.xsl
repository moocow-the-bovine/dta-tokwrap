<?xml version="1.0" encoding="ISO-8859-1"?>
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
    <dta.tw.serialized>
      <s/>
      <xsl:comment>MAIN</xsl:comment>
      <xsl:apply-templates mode="main" select="*"/>
      <s/>
      <xsl:comment>END</xsl:comment>
      <xsl:apply-templates mode="end" select="*"/>
      <s/>
    </dta.tw.serialized>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- MAIN -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: main: ignore non-MAIN stuff -->
  <xsl:template mode="main" match="*[@where!='MAIN']" priority="100">
    <xsl:apply-templates mode="main" select="*"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: main: loc: copy -->
  <xsl:template mode="main" match="dta.tw.b|lb">
    <xsl:copy-of select="."/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: main: implicit sentence breaks -->
  <xsl:template mode="main" match="div|p|text|front|back|body">
    <s/><xsl:apply-templates mode="main" select="*"/><s/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: main: implicit token breaks -->
  <xsl:template mode="main" match="cit|q|quote|head">
    <w/><xsl:apply-templates mode="main" select="*"/><w/>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- MAIN: defaults -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- default: main: elements: just recurse -->
  <xsl:template mode="main" match="*" priority="-1">
    <xsl:apply-templates mode="main" />
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- default: main: other: ignore -->
  <xsl:template mode="main" match="@*|text()|comment()|processing-instruction()" priority="-1"/>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- END -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: end: ignore non-END stuff -->
  <xsl:template mode="end" match="*[@where!='END']" priority="100">
    <xsl:apply-templates mode="end" select="*"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: end: loc: copy -->
  <xsl:template mode="end" match="lb|dta.tw.b">
    <xsl:copy-of select="."/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: end: note, no seg -->
  <xsl:template mode="end" match="note[not(ancestor::seg)]">
    <s/><xsl:apply-templates mode="end" select="*"/><s/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: end: seg -->
  <xsl:template mode="end" match="seg[@part='I']">
    <s/><xsl:apply-templates mode="end" select="*"/>
  </xsl:template>

  <xsl:template mode="end" match="seg[@part='F']">
    <xsl:apply-templates mode="end" select="*"/><s/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: end: table -->
  <xsl:template mode="end" match="table">
    <s/><xsl:apply-templates mode="end" select="*"/><s/>
  </xsl:template>

  <xsl:template mode="end" match="row|cell">
    <w/><xsl:apply-templates mode="end" select="*"/><w/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: end: list, item -->
  <xsl:template mode="end" match="list">
    <w/><xsl:apply-templates mode="end" select="*"/><w/>
  </xsl:template>
  <xsl:template mode="end" match="item">
    <w/><xsl:apply-templates mode="end" select="*"/><w/>
  </xsl:template>


  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- END: defaults -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- default: end: elements: just recurse -->
  <xsl:template mode="end" match="*" priority="-1">
    <xsl:apply-templates mode="end" select="*"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- default: end: other: ignore -->
  <xsl:template mode="end" match="@*|text()|comment()|processing-instruction()" priority="-1"/>

</xsl:stylesheet>
