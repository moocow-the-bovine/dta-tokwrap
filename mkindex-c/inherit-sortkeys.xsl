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
  <xsl:param    name="keyName"       select="'dta.tw.key'"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <!--<xsl:strip-space elements="text div p seg note table row cell"/>-->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->
  <xsl:template match="/">
    <xsl:apply-templates select="*|@*"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: element: inherit sort keys -->
  <xsl:template match="*">
    <xsl:copy>
      <!--<xsl:attribute name="{$keyName}"><xsl:value-of select="ancestor-or-self::*[@dta.tw.key]][1]/@dta.tw.key"/></xsl:attribute>-->
      <xsl:attribute name="{$keyName}"><xsl:value-of select="ancestor-or-self::*[attribute::*[name()=$keyName]][1]/attribute::*[name()=$keyName]"/></xsl:attribute>
      <xsl:apply-templates select="*|@*[not(name()=$keyName)]"/>
    </xsl:copy>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- default: attributes : copy -->
  <xsl:template match="@*" priority="-1">
    <xsl:copy-of select="."/>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- default: other: ignore -->
  <xsl:template match="text()|processing-instruction()|comment()" priority="-1"/>

</xsl:stylesheet>
