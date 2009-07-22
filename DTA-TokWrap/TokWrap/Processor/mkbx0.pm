## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor::mkbx0.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA tokenizer wrappers: sxfile -> bx0doc

package DTA::TokWrap::Processor::mkbx0;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :libxml :libxslt :slurp :time);
use DTA::TokWrap::Processor;

use XML::LibXML;
use XML::LibXSLT;
use IO::File;

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor);

##==============================================================================
## Constructors etc.
##==============================================================================

## $mbx0 = CLASS_OR_OBJ->new(%args)
## %defaults = CLASS->defaults()
##  + %args, %defaults, %$mbx0:
##    (
##     ##-- Programs
##     rmns    => $path_to_xml_rm_namespaces, ##-- default: search
##     inplace => $bool,                      ##-- prefer in-place programs for search?
##     ##
##     ##-- Styleheet: insert-hints (<seg> elements and their children are handled implicitly)
##     hint_sb_xpaths => \@xpaths,            ##-- add sentence-break hint (<s/>) for @xpath element open & close
##     hint_wb_xpaths => \@xpaths,            ##-- ad word-break hint (<w/>) for @xpath element open & close
##     hint_lb_xpaths => \@xpaths,            ##-- ad line-break hint (<lb/>) for @xpath element *close*
##     ##
##     hint_stylestr  => $stylestr,           ##-- xsl stylesheet string
##     hint_styleheet => $stylesheet,         ##-- compiled xsl stylesheet
##     ##
##     ##-- Stylesheet: mark-sortkeys (<seg> elements and their children are handled implicitly)
##     sortkey_attr => $attr,                 ##-- sort-key attribute (default: 'dta.tw.key')
##     sort_ignore_xpaths => \@xpaths,        ##-- ignore these xpaths
##     sort_addkey_xpaths => \@xpaths,        ##-- add new sort key for @xpaths
##     ##
##     sort_stylestr  => $stylestr,           ##-- xsl stylesheet string
##     sort_styleheet => $stylesheet,         ##-- compiled xsl stylesheet
##   )
sub defaults {
  my $that = shift;
  return (
	  ##-- inherited
	  $that->SUPER::defaults(),

	  ##-- programs
	  rmns   =>undef,
	  inplace=>1,

	  ##-- stylesheet: insert-hints
	  hint_sb_xpaths => [
			     ##-- title page
			     qw(titlePage byline titlePart docAuthor docImprint pubPlace publisher docDate),

			     ##-- main text: common
			     qw(div|p|text|front|back|body),

			     ##-- notes, tables, lists, etc.
			     qw(note|table|argument),
			     qw(figure),

			     ##-- drama-specific
			     ## + e.g. goethe_iphegenie, schiller_kabale, hauptman_sonnenaufgang
			     #qw(speaker sp stage castList castGroup castItem role roleDesc set),
			     #qw(speaker sp stage castList castGroup castItem role roleDesc set),
			     qw(castList|castList/head|castGroup),
			     'castItem[not(parent::castGroup)]',
			    ],
	  hint_wb_xpaths => [
			     ##-- main text: common
			     qw(head|fw),

			     ##-- citations & quotes (TODO: check real examples)
			     qw(cit|q|quote),

			     ##-- letters (TODO: check real examples)
			     qw(salute dateline opener closer signed),

			     ##-- notes, tables, lists, etc.
			     qw(row|cell),
			     qw(list|item), ##-- maybe move one or both of these to 'sb_xpaths' ?

			     ##-- drama-specific
			     ## + e.g. goethe_iphegenie, schiller_kabale, hauptman_sonnenaufgang
			     #qw(speaker sp stage castList castGroup castItem role roleDesc set),
			     qw(sp|speaker|stage|set),
			     qw(castGroup/castItem|role|roleDesc),
			    ],
	  hint_lb_xpaths => [
			     ##-- segments
			     'seg',

			     ##-- other things
			     map { "$_\[not(parent::seg)\]" } qw(table note argument figure),
			    ],
	  hint_stylestr => undef,
	  hint_stylesheet => undef,

	  ##-- stylesheet: mark-sortkeys
	  sortkey_attr => 'dta.tw.key',
	  sort_ignore_xpaths => [
				 qw(ref|fw|head),
				],
	  sort_addkey_xpaths => [
				 (map {"$_\[not(parent::seg)\]"} qw(table note argument figure)),
				 qw(text front body back),
				],
	  sort_stylestr  => undef,
	  sort_styleheet => undef,
	 );
}

## $mbx0 = $mbx0->init()
sub init {
  my $mbx0 = shift;

  ##-- search for xml-rm-namespaces program
  if (!defined($mbx0->{rmns})) {
    $mbx0->{rmns} = path_prog('dtatw-rm-namespaces',
			    prepend=>($mbx0->{inplace} ? ['.','../src'] : undef),
			    warnsub=>sub {$mbx0->logconfess(@_)},
			   );
  }

  ##-- create stylesheet strings
  $mbx0->{hint_stylestr}   = $mbx0->hint_stylestr() if (!$mbx0->{hint_stylestr});
  $mbx0->{sort_stylestr}   = $mbx0->sort_stylestr() if (!$mbx0->{sort_stylestr});

  ##-- compile stylesheets
  #$mbx0->{hint_stylesheet} = xsl_stylesheet(string=>$mbx0->{hint_stylestr}) if (!$mbx0->{hint_stylesheet});
  #$mbx0->{sort_stylesheet} = xsl_stylesheet(string=>$mbx0->{sort_stylestr}) if (!$mbx0->{sort_stylesheet});

  return $mbx0;
}

##==============================================================================
## Methods: XSL stylesheets
##==============================================================================

##--------------------------------------------------------------
## Methods: XSL stylesheets: common

## $mbx0_or_undef = $mbx0->ensure_stylesheets()
sub ensure_stylesheets {
  my $mbx0 = shift;
  $mbx0->{hint_stylesheet} = xsl_stylesheet(string=>$mbx0->{hint_stylestr}) if (!$mbx0->{hint_stylesheet});
  $mbx0->{sort_stylesheet} = xsl_stylesheet(string=>$mbx0->{sort_stylestr}) if (!$mbx0->{sort_stylesheet});
  return $mbx0;
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: insert-hints
sub hint_stylestr {
  my $mbx0 = shift;
  return '<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" version="1.0" indent="no" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->
  <xsl:template match="/">
    <xsl:apply-templates select="*|@*"/>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: implicit sentence breaks -->'.join('',
						     map { "
  <xsl:template match=\"$_\">
    <xsl:copy>
      <xsl:apply-templates select=\"@*\"/>
      <s/>
      <xsl:apply-templates select=\"*\"/>
      <s/>
    </xsl:copy>
  </xsl:template>\n"
							 } @{$mbx0->{hint_sb_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: implicit token breaks -->'.join('',
						     map { "
  <xsl:template match=\"$_\">
    <xsl:copy>
      <xsl:apply-templates select=\"@*\"/>
      <w/>
      <xsl:apply-templates select=\"*\"/>
      <w/>
    </xsl:copy>
  </xsl:template>\n"
							 } @{$mbx0->{hint_wb_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: implicit line breaks -->'.join('',
						     map { "
  <xsl:template match=\"$_\">
    <xsl:copy>
      <xsl:apply-templates select=\"@*|*\"/>
      <lb/>
    </xsl:copy>
  </xsl:template>\n"
							 } @{$mbx0->{hint_lb_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: seg (priority=10) -->
  <xsl:template match="seg[@part=\'I\']" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <s/>
      <xsl:apply-templates select="*"/>
      <lb/>
    </xsl:copy>
  </xsl:template>

  <!-- seg[@part=\'M\'] is handled by defaults -->

  <xsl:template match="seg[@part=\'F\']" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
      <s/>
      <lb/>
    </xsl:copy>
  </xsl:template>

  <!-- avoid implicit breaks for explicitly segmented material -->
  <xsl:template match="seg/*|seg/@*" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: OTHER: castGroup (priority=10) -->
  <xsl:template match="castGroup[count(./roleDesc)=1]" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <s/>
      <xsl:apply-templates select="*[name()!=\'roleDesc\']"/>
      <xsl:apply-templates select="roleDesc"/>
      <s/>
    </xsl:copy>
  </xsl:template>


  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: DEFAULT: copy -->
  <xsl:template match="*|@*" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
';
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: mark-sortkeys
sub sort_stylestr {
  my $mbx0 = shift;
  my $keyName = $mbx0->{sortkey_attr};
  return '<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" version="1.0" indent="no" encoding="UTF-8"/>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: root: traverse -->

  <xsl:template match="/*">
    <xsl:copy>
      <xsl:attribute name="'.$keyName.'"><xsl:call-template name="generate-key"/></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: ignored material (priority=100) -->

  '.join("\n  ",
	 (map {"<xsl:template match=\"$_\" priority=\"100\"/>"} @{$mbx0->{sort_ignore_xpaths}})).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: seg (priority=10) -->

  <xsl:template match="seg[@part=\'I\']" priority="10">
    <xsl:copy>
      <xsl:attribute name="'.$keyName.'"><xsl:call-template name="generate-key"/></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="seg[@part=\'M\' or @part=\'F\']" priority="10">
    <xsl:variable name="keyNode" select="preceding::seg[@part=\'I\'][1]"/>
    <xsl:copy>
      <xsl:attribute name="'.$keyName.'"><xsl:call-template name="generate-key"><xsl:with-param name="node" select="$keyNode"/></xsl:call-template></xsl:attribute>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- templates: material to adjoin (sort_addkey) -->
'.join('',
					       map {"
  <xsl:template match=\"$_\">
    <xsl:copy>
      <xsl:attribute name=\"$keyName\"><xsl:call-template name=\"generate-key\"/></xsl:attribute>
      <xsl:apply-templates select=\"*|@*\"/>
    </xsl:copy>
  </xsl:template>\n"
						  } @{$mbx0->{sort_addkey_xpaths}}).'

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: DEFAULT: copy -->

  <xsl:template match="*|@*" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="*|@*"/>
    </xsl:copy>
  </xsl:template>

  <!--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-->
  <!-- template: NAMED: generate-key -->

  <xsl:template name="generate-key">
    <xsl:param name="node" select="."/>
    <xsl:value-of select="concat(name($node),\'.\',generate-id($node))"/>
  </xsl:template>

</xsl:stylesheet>
';
}

##--------------------------------------------------------------
## Methods: XSL stylesheets: debug

## undef = $mbx0->dump_string($str,$filename_or_fh)
sub dump_string {
  my ($mbx0,$str,$file) = @_;
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  $fh->print($str);
  $fh->close() if (!ref($file));
}

## undef = $mbx0->dump_hint_stylesheet($filename_or_fh)
sub dump_hint_stylesheet {
  $_[0]->dump_string($_[0]{hint_stylestr}, $_[1]);
}

## undef = $mbx0->dump_sort_stylesheet($filename_or_fh)
sub dump_sort_stylesheet {
  $_[0]->dump_string($_[0]{sort_stylestr}, $_[1]);
}

##==============================================================================
## Methods: mkbx0 (apply stylesheets)
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->mkbx0($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    sxfile  => $sxfile,  ##-- (input) structure index filename
##    bx0doc  => $bx0doc,  ##-- (output) preliminary block-index data (XML::LibXML::Document)
##    mkbx0_stamp0 => $f,  ##-- (output) timestamp of operation begin
##    mkbx0_stamp  => $f,  ##-- (output) timestamp of operation end
##    bx0doc_stamp => $f,  ##-- (output) timestamp of operation end
sub mkbx0 {
  my ($mbx0,$doc) = @_;

  ##-- log, stamp
  $mbx0->vlog($mbx0->{traceLevel},"mkbx0($doc->{xmlbase})");
  $doc->{mkbx0_stamp0} = timestamp();

  ##-- sanity check(s)
  $mbx0 = $mbx0->new() if (!ref($mbx0));
  $mbx0->logconfess("mkbx0($doc->{xmlbase}): no dtatw-rm-namespaces program")
    if (!$mbx0->{rmns});
  $mbx0->logconfess("mkbx0($doc->{xmlbase}): could not compile XSL stylesheets")
    if (!$mbx0->ensure_stylesheets);
  $mbx0->logconfess("mbx0($doc->{xmlbase}): no .sx file defined")
    if (!$doc->{sxfile});
  $mbx0->logconfess("mbx0($doc->{xmlbase}): .sx file unreadable: $!")
    if (!-r $doc->{sxfile});

  ##-- run command, buffer output to string
  my $cmdfh = IO::File->new("'$mbx0->{rmns}' '$doc->{sxfile}'|")
    or $mbx0->logconfess("mkbx0($doc->{xmlbase}): open failed for pipe from '$mbx0->{rmns}': $!");
  my $sxbuf = '';
  slurp_fh($cmdfh, \$sxbuf);
  $cmdfh->close();

  ##-- parse buffer
  my $xmlparser = libxml_parser(keep_blanks=>0);
  my $sxdoc = $xmlparser->parse_string($sxbuf)
    or $mbx0->logconfess("mkbx0($doc->{xmlbase}): could not parse namespace-hacked .sx document '$doc->{sxfile}': $!");

  ##-- apply XSL stylesheets
  $sxdoc = $mbx0->{hint_stylesheet}->transform($sxdoc)
    or $mbx0->logconfess("mkbx0($doc->{xmlbase}): could not apply hint stylesheet to .sx document '$doc->{sxfile}': $!");
  $sxdoc = $mbx0->{sort_stylesheet}->transform($sxdoc)
    or $mbx0->logconfess("mkbx0($doc->{xmlfile}): could not apply sortkey stylesheet to .sx document '$doc->{sxfile}': $!");

  ##-- adjust $doc
  $doc->{bx0doc} = $sxdoc;
  $doc->{mkbx0_stamp} = $doc->{bx0doc_stamp} = timestamp(); ##-- stamp
  return $doc;
}

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, and edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Processor::mkbx0 - DTA tokenizer wrappers: sxfile -> bx0doc

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Processor::mkbx0;
 
 $mbx0 = DTA::TokWrap::Processor::mkbx0->new(%opts);
 $doc_or_undef = $mbx0->mkbx0($doc);
 
 ##-- debugging
 $mbx0_or_undef = $mbx0->ensure_stylesheets();
 $mbx0->dump_hint_stylesheet($filename_or_fh);
 $mbx0->dump_sort_stylesheet($filename_or_fh);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::TokWrap::Processor::mkindex provides an object-oriented
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor> wrapper
for
hint insertion and serialization sort-key generation
on a text-free "structure index" (.sx) XML file.

Most users should use the high-level
L<DTA::TokWrap|DTA::TokWrap> wrapper class
instead of using this module directly.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkbx0: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Processor::mkbx0
inherits from
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkbx0: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $mbx0 = $CLASS_OR_OBJ->new(%opts)

Constructor.

%opts, %$mbx0:

 ##-- Programs
 rmns    => $path_to_xml_rm_namespaces, ##-- default: search
 inplace => $bool,                      ##-- prefer in-place programs for search?
 ##
 ##-- Styleheet: insert-hints (<seg> elements and their children are handled implicitly)
 hint_sb_xpaths => \@xpaths,            ##-- add sentence-break hint (<s/>) for @xpath element open & close
 hint_wb_xpaths => \@xpaths,            ##-- ad word-break hint (<w/>) for @xpath element open & close
 ##
 hint_stylestr  => $stylestr,           ##-- xsl stylesheet string
 hint_styleheet => $stylesheet,         ##-- compiled xsl stylesheet
 ##
 ##-- Stylesheet: mark-sortkeys (<seg> elements and their children are handled implicitly)
 sortkey_attr => $attr,                 ##-- sort-key attribute (default: 'dta.tw.key')
 sort_ignore_xpaths => \@xpaths,        ##-- ignore these xpaths
 sort_addkey_xpaths => \@xpaths,        ##-- add new sort key for @xpaths
 ##
 sort_stylestr  => $stylestr,           ##-- xsl stylesheet string
 sort_styleheet => $stylesheet,         ##-- compiled xsl stylesheet

=item defaults

 %defaults = CLASS->defaults();

Static class-dependent defaults.

=item init

 $mbx0 = $mbx0->init();

Dynamic object-dependent defaults.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkbx0: Methods: XSL stylesheets
=pod

=head2 Methods: XSL stylesheets

=over 4

=item ensure_stylesheets

 $mbx0_or_undef = $mbx0->ensure_stylesheets();

Ensures that required XSL stylesheets have been compiled.

=item hint_stylestr

 $xsl_str = $mbx0->hint_stylestr();

Returns XSL stylesheet string for the 'insert-hints' transformation,
which is responsible for inserting sentence- and token-break hints
into the input *.sx document.

=item sort_stylestr

 $xsl_str = $mbx0->sort_stylestr();

Returns XSL stylesheet string for the 'generate-sort-keys' transformation,
which is responsible for inserting top-level serialization-segment keys
into the input *.sx document.

=item dump_hint_stylesheet

 $mbx0->dump_hint_stylesheet($filename_or_fh);

Dumps the generated 'insert-hints' stylesheet to $filename_or_fh.

=item dump_sort_stylesheet

 $mbx0->dump_sort_stylesheet($filename_or_fh);

Dumps the generated 'generate-sortkeys' stylesheet to $filename_or_fh.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkbx0: Methods: mkbx0 (apply stylesheets)
=pod

=head2 Methods: top-level

=over 4

=item mkbx0

 $doc_or_undef = $CLASS_OR_OBJECT->mkbx0($doc);

Applies the XSL pipeline for hint insertion and
sort-key generation to the "structure index" (*.sx)
document of the
L<DTA::TokWrap::Document|DTA::TokWrap::Document> object
$doc.

Relevant %$doc keys:

 sxfile  => $sxfile,  ##-- (input) structure index filename
 bx0doc  => $bx0doc,  ##-- (output) preliminary block-index data (XML::LibXML::Document)
 ##
 mkbx0_stamp0 => $f,  ##-- (output) timestamp of operation begin
 mkbx0_stamp  => $f,  ##-- (output) timestamp of operation end
 bx0doc_stamp => $f,  ##-- (output) timestamp of operation end

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## See Also
##======================================================================

=pod

=head1 SEE ALSO

L<DTA::TokWrap::Intro(3pm)|DTA::TokWrap::Intro>,
L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
...

=cut

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
