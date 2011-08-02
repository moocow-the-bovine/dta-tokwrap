<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="html" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- parameters -->
  <xsl:param name="dtaid" select="16223"/>
  <xsl:param name="snippet_perl" select="'http://kaskade.dwds.de/~moocow/opensearch/snippet.perl'"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- options -->
  <xsl:strip-space elements="sentences s w a"/>

  <!--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Mode: main -->

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: root: traverse -->
  <xsl:template match="/*">
    <html>
      <head>
	<title>Formulae for dtaid=<xsl:value-of select="$dtaid"/></title>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<style type="text/css">
a { color:#000000; text-decoration:none; }
a[href]:hover { background-color:#00ffff; }
.formula { font-weight:bold; color:#ff0000; }
table {width:100%; border-collapse:collapse;}
p {margin-bottom: 5px;}
tr {vertical-align:top;}
th {font-weight:bold;}
td.context {}
td.snippet {}
td.snippet img {width:600px; border: 1px solid grey; margin-left:5px;}
</style>
      </head>
      <body>
	<h1>Formulae for dtaid=<xsl:value-of select="$dtaid"/></h1>
	<table>
	  <tbody>
	    <xsl:apply-templates select="//w[@t='FORMULA']"/>
	    <!--<xsl:apply-templates select="//w[@id='w116' or @id='w660' or @id='w743']"/>-->
	  </tbody>
	</table>
      </body>
    </html>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: s with formulae -->
  <xsl:template match="//w[@t='FORMULA']">
    <tr>
      <th><xsl:value-of select="../@id"/>:<xsl:value-of select="@id"/></th>
      <td class="context">
	<xsl:for-each select="preceding-sibling::w">
	  <xsl:call-template name="word_template">
	    <xsl:with-param name="w" select="."/>
	    <xsl:with-param name="class">w</xsl:with-param>
	  </xsl:call-template>
	</xsl:for-each>

	<xsl:call-template name="word_template">
	  <xsl:with-param name="w" select="."/>
	  <xsl:with-param name="class">formula</xsl:with-param>
	</xsl:call-template>

	<xsl:for-each select="following-sibling::w">
	  <xsl:call-template name="word_template">
	    <xsl:with-param name="w" select="."/>
	    <xsl:with-param name="class">w</xsl:with-param>
	  </xsl:call-template>
	</xsl:for-each>
	<p/>
      </td>

      <td class="snippet" align="right">
	<xsl:variable name="snipurl">
	  <xsl:value-of select="$snippet_perl"/>
	  <xsl:text>?wid=</xsl:text><xsl:value-of select="./@id"/>
	  <xsl:text>&amp;res=50</xsl:text>
	  <xsl:text>&amp;dtaid=</xsl:text><xsl:value-of select="$dtaid"/>
	  <xsl:text>&amp;page=</xsl:text><xsl:value-of select="./@pb"/>
	  <xsl:text>&amp;bbox=</xsl:text><xsl:value-of select="./@bb"/>
	</xsl:variable>
	<xsl:element name="a">
	  <xsl:attribute name="href"><xsl:value-of select="$snipurl"/></xsl:attribute>
	  <xsl:element name="img">
	    <xsl:attribute name="src"><xsl:value-of select="$snipurl"/></xsl:attribute>
	  </xsl:element>
	</xsl:element>
      </td>
    </tr>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: template: w -->
  <xsl:template name="word_template">
    <xsl:param name="w"     select="."/>
    <xsl:param name="class"/>
    <xsl:element name="a">
      <xsl:attribute name="title">id=<xsl:value-of select="$w/@id"/>; pb=<xsl:value-of select="$w/@pb"/>; lb=<xsl:value-of select="$w/@lb"/>; bb=<xsl:value-of select="$w/@bb"/></xsl:attribute>
      <xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute>
      <xsl:attribute name="style">
	<xsl:if test="not(@bb) or @bb=''"><xsl:text>color:#cc00cc;</xsl:text></xsl:if>
      </xsl:attribute>
      <xsl:attribute name="href">
	<xsl:value-of select="$snippet_perl"/>
	<xsl:text>?wid=</xsl:text><xsl:value-of select="./@id"/>
	<xsl:text>&amp;res=50</xsl:text>
	<xsl:text>&amp;dtaid=</xsl:text><xsl:value-of select="$dtaid"/>
	<xsl:text>&amp;page=</xsl:text><xsl:value-of select="./@pb"/>
	<xsl:text>&amp;bbox=</xsl:text><xsl:value-of select="./@bb"/>
      </xsl:attribute>
      <xsl:value-of select="./@t"/>
    </xsl:element>
    <xsl:text> </xsl:text>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- main: default: ignore -->
  <xsl:template match="*|@*|text()|processing-instruction()|comment()" priority="-1"/>

</xsl:stylesheet>
