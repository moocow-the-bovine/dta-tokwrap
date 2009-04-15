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
      <xsl:copy-of select="@xml:id"/>
      <xsl:copy-of select="@t"/>
      <xsl:call-template name="w-ref"/>
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
  <xsl:template name="w-ref">
    <xsl:param name="ref" select="concat(@ref,' ')"/>
    <xsl:if test="$ref != ''">
      <xsl:element name="c">
	<xsl:attribute name="ref"><xsl:value-of select="substring-before($ref,' ')"/></xsl:attribute>
      </xsl:element>
      <xsl:call-template name="w-ref">
	<xsl:with-param name="ref" select="substring-after($ref,' ')"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
