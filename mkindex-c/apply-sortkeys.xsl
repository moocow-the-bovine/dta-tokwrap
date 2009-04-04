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

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <!--<xsl:strip-space elements="text div p seg note table row cell loc lb pb"/>-->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->
  <xsl:template match="/">
    <dta.tw.serialized>
      <s/>
      <xsl:comment>MAIN</xsl:comment>
      <xsl:apply-templates mode="MAIN" />
      <s/>
      <xsl:comment>OTHER</xsl:comment>
      <xsl:apply-templates mode="OTHER" />
      <s/>
    </dta.tw.serialized>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Mode MAIN -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: MAIN: ignore non-MAIN stuff -->
  <xsl:template mode="MAIN" match="*[@dta.tw.key != '-']" priority="100">
    <xsl:apply-templates mode="MAIN" />
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: MAIN: text-pointers: copy -->
  <xsl:template mode="MAIN" match="c|w|s">
    <xsl:copy-of select="."/>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- MAIN: defaults -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- default: MAIN: elements: copy -->
  <xsl:template mode="MAIN" match="*|@*" priority="-1">
    <xsl:copy>
      <xsl:apply-templates mode="MAIN" select="*|@*" />
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- default: MAIN: other: ignore -->
  <xsl:template mode="MAIN" match="text()|comment()|processing-instruction()" priority="-1"/>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Mode OTHER -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: ignore non-OTHER stuff -->
  <xsl:template mode="OTHER" match="*[@dta.tw.key = '-']" priority="100">
    <xsl:apply-templates mode="OTHER" select="*"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: text-pointers: copy -->
  <xsl:template mode="OTHER" match="c|w|s">
    <xsl:copy-of select="."/>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- OTHER: defaults -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- defaults: OTHER: elements: copy -->
  <xsl:template mode="OTHER" match="*|@*" priority="-1">
    <xsl:copy>
      <xsl:apply-templates mode="OTHER" select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- default: end: other: ignore -->
  <xsl:template mode="OTHER" match="text()|comment()|processing-instruction()" priority="-1"/>

</xsl:stylesheet>
