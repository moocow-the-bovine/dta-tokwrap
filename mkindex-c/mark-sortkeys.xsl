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
  <xsl:param    name="keyName"    select="'dta.tw.key'"/>
  <xsl:variable name="defaultVal" select="'-'"/>
  <xsl:param    name="keyVal"     select="defaultVal"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <!--<xsl:strip-space elements="text div p seg note table row cell"/>-->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->
  <xsl:template match="/*">
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:value-of select="$defaultVal"/></xsl:attribute>
      <xsl:apply-templates select="*|@*">
	<xsl:with-param name="keyVal" select="$defaultVal"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: ignored material -->
  <xsl:template match="ref|fw" priority="100"/>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- templates: quasi-independent segments -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: seg (priority=10) -->
  <xsl:template match="seg[@part='I']" priority="10">
    <xsl:variable name="keyVal" select="generate-id(.)"/> <!-- clobber -->
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:value-of select="$keyVal"/></xsl:attribute>
      <xsl:apply-templates select="*|@*">
	<xsl:with-param name="keyVal" select="$keyVal"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="seg[@part='M' or @part='F']" priority="10">
    <xsl:variable name="keyVal" select="generate-id(preceding::seg[@part='I'][1])"/> <!-- clobber -->
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:value-of select="$keyVal"/></xsl:attribute>
      <xsl:apply-templates select="*|@*">
	<xsl:with-param name="keyVal" select="$keyVal"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: table, no seg: clobber sort key -->
  <xsl:template match="table[not(parent::seg)]">
    <xsl:variable name="keyVal" select="generate-id(.)"/> <!-- clobber -->
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:value-of select="$keyVal"/></xsl:attribute>
      <xsl:apply-templates select="*|@*">
	<xsl:with-param name="keyVal" select="$keyVal"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: note, no seg: clobber sort key -->
  <xsl:template match="note[not(parent::seg)]">
    <xsl:variable name="keyVal" select="generate-id(.)"/>
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:value-of select="$keyVal"/></xsl:attribute>
      <xsl:apply-templates select="*|@*">
	<xsl:with-param name="keyVal" select="$keyVal"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- defaults -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- defaults: elements: copy, propagating sort-key value -->
  <xsl:template match="*" priority="-1">
    <xsl:param name="keyVal" select="$defaultVal"/>
    <xsl:copy>
      <xsl:attribute name="{$keyName}"><xsl:value-of select="$keyVal"/></xsl:attribute>
      <xsl:apply-templates select="*|@*">
	<xsl:with-param name="keyVal" select="$keyVal"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- defaults: attributes: copy -->
  <xsl:template match="@*" priority="-1">
    <xsl:copy-of select="."/>
  </xsl:template>

</xsl:stylesheet>
