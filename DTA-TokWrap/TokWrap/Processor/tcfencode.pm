## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor::tcfencode.pm
## Author: Bryan Jurish <jurish@bbaw.de>
## Description: DTA tokenizer wrappers: TEI->TCF[tei,text] encoding

package DTA::TokWrap::Processor::tcfencode;

use DTA::TokWrap::Version;  ##-- imports $VERSION, $RCDIR
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:slurp :time :libxml);
use DTA::TokWrap::Processor;

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor);

##==============================================================================
## Constructors etc.
##==============================================================================

## $enc = CLASS_OR_OBJ->new(%args)
##  + %args, %deaults, %$enc:
##    (
##     tcfTextSourceType => $type, ##-- attribute value for encoded //textSource/@type (default="text/tei+xml; tokenized=0")
##    )

## %defaults = CLASS_OR_OBJ->defaults()
##  + called by constructor
##  + inherited dummy method
sub defaults {
  return (
	  tcfTextSourceType => 'text/tei+xml; tokenized=0',
	 );
}

## $enc = $enc->init()
##  + inherited dummy method
#sub init { $_[0] }

##==============================================================================
## Methods
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->tcfencode($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    xmlfile => $xmlfile, ##-- (input) source TEI-XML file
##    xmldata => $xmldata, ##-- (input,alternate) source TXT-XML buffer
##    txtfile => $txtfile, ##-- (input) serialized text file
##    txtdata => $txtdata, ##-- (input,alternate) serialized text data
##    tcflang => $lang,    ##-- (input) tcf language (default="de")
##    ##
##    tcfdoc  => $tcfdoc,   ##-- (output) TCF output document
##    tcfencode_stamp0 => $f, ##-- (output) timestamp of operation begin
##    tcfencode_stamp  => $f, ##-- (output) timestamp of operation end
##    tcfdoc_stamp   => $f, ##-- (output) timestamp of operation end
sub tcfencode {
  my ($enc,$doc) = @_;
  $enc = $enc->new if (!ref($enc));
  $doc->setLogContext();

  ##-- log, stamp
  $enc->vlog($enc->{traceLevel},"tcfencode()");
  $doc->{tcfencode_stamp0} = timestamp(); ##-- stamp

  ##-- create TCF document (lifted from DTA::CAB::Format::TCF::putDocument())
  my $xdoc = $doc->{tcfdoc} = XML::LibXML::Document->new("1.0","UTF-8");
  my $xroot = $xdoc->createElement('D-Spin');
  $xdoc->setDocumentElement($xroot);
  $xroot->setNamespace('http://www.dspin.de/data');
  $xroot->setAttribute('version'=>'0.4');

  ##-- document structure: metadata
  my $xmeta = $xroot->addNewChild(undef,'MetaData');
  $xmeta->setNamespace('http://www.dspin.de/data/metadata');
  $xmeta->appendTextChild('source', $doc->{source}) if (defined($doc->{source}));

  ##-- document structure: TextCorpus
  my $xcorpus = $xroot->addNewChild(undef,'TextCorpus');
  $xcorpus->setNamespace('http://www.dspin.de/data/textcorpus');
  $xcorpus->setAttribute('lang'=>($doc->{tcflang}//'de'));

  ##-- document structure: TextCorpus/textSource
  my $xtei = $xcorpus->addNewChild(undef,'textSource');
  $xtei->setAttribute('type'=>$enc->{tcfTextSourceType}) if ($enc->{tcfTextSourceType});
  ##
  my $xmldata_is_tmp = !defined($doc->{xmldata});
  $enc->logconfess("tcfencode(): could not load TEI-XML source file '$doc->{xmlfile}' and {xmldata} key undefined")
    if ($xmldata_is_tmp && !$doc->loadXmlData());
  $xtei->appendText( $doc->{xmldata} );
  delete($doc->{xmldata}) if ($xmldata_is_tmp);

  ##-- document structure: TextCorpus/text
  my $xtxt = $xcorpus->addNewChild(undef,'text');
  ##
  my $txtdata_is_tmp = !defined($doc->{txtdata});
  $enc->logconfess("tcfencode(): could not load serialized text file '$doc->{txtfile}' and {txtdata} key undefined")
    if ($txtdata_is_tmp && !$doc->loadTxtData());
  $xtxt->appendText( $doc->{txtdata} );
  ##
  delete($doc->{txtdata}) if ($txtdata_is_tmp);

  ##-- finalize
  $doc->{tcfencode_stamp} = $doc->{tcfdoc_stamp} = timestamp(); ##-- stamp
  return $doc;
}

##==============================================================================
## Utilities
##==============================================================================

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Processor::tcfencode - DTA tokenizer wrappers: TEI-E<gt>TCF encoding

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Processor::tcfencode;
 
 $enc = DTA::TokWrap::Processor::tcfencode->new(%opts);
 $doc_or_undef = $dec->tcfencode($doc);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::TokWrap::Processor::tcfencode provides an object-oriented
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor> wrapper
for encoding (serialized) TEI-XML as TCF ("Text Corpus Format",
cf. http://weblicht.sfs.uni-tuebingen.de/weblichtwiki/index.php/The_TCF_Format)
using L<DTA::TokWrap::Document|DTA::TokWrap::Document> objects.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tcfencode: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Processor::tcfencode
inherits from
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tcfencode: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $obj = $CLASS_OR_OBJECT->new(%args);

Constructor.

=item defaults

 %defaults = $CLASS->defaults();

Static class-dependent defaults.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tcfencode: Methods
=pod

=head2 Methods

=over 4

=item tcfencode

 $doc_or_undef = $CLASS_OR_OBJECT->tcfencode($doc);

Converts the
L<DTA::TokWrap::Document|DTA::TokWrap::Document> object
to TCF, storing the result as an
XML::LibXML::Document in
C<$doc-E<gt>{tcfdoc}>.

Relevant %$doc keys:

 xmlfile => $xmlfile, ##-- (input) source TEI-XML file
 txtfile => $txtfile, ##-- (input) serialized text file
 xmldata => $xmldata, ##-- (input,alternate) source TXT-XML buffer
 txtdata => $txtdata, ##-- (input,alternate) serialized text data
 ##
 tcfdoc  => $tcfdoc,   ##-- (output) TCF output document
 tcfencode_stamp0 => $f, ##-- (output) timestamp of operation begin
 tcfencode_stamp  => $f, ##-- (output) timestamp of operation end
 tcfdoc_stamp   => $f, ##-- (output) timestamp of operation end

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

Copyright (C) 2014 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut


