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
      <xsl:copy-of select="@t"/>
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
