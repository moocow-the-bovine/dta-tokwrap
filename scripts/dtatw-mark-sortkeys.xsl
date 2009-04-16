<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output
    method="xml"
    version="1.0"
    indent="no"
    encoding="UTF-8"
    />

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- parameters & variables -->
  <xsl:param    name="keyName"       select="'dta.tw.key'"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <!--<xsl:strip-space elements="text div p seg note table row cell"/>-->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->
  <xsl:template match="/*">
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:call-template name="generate-key"/></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: ignored material -->
  <xsl:template match="ref|fw|head" priority="100"/>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- templates: quasi-independent segments -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: seg (priority=10) -->
  <xsl:template match="seg[@part='I']" priority="10">
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:call-template name="generate-key"/></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="seg[@part='M' or @part='F']" priority="10">
    <xsl:variable name="keyNode" select="preceding::seg[@part='I'][1]"/> <!-- clobber -->
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:call-template name="generate-key"><xsl:with-param name="node" select="$keyNode"/></xsl:call-template></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: table, no seg: clobber sort key -->
  <xsl:template match="table[not(parent::seg)]">
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:call-template name="generate-key"/></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: note, no seg: clobber sort key -->
  <xsl:template match="note[not(parent::seg)]">
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:call-template name="generate-key"/></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
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

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- templates: named: key-generation -->
  <xsl:template name="generate-key">
    <xsl:param name="node" select="."/>
    <xsl:value-of select="concat(name($node),'.',generate-id($node))"/>
  </xsl:template>

</xsl:stylesheet>
