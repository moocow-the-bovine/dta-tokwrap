## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor::tcfdecode.pm
## Author: Bryan Jurish <jurish@bbaw.de>
## Description: DTA tokenizer wrappers: TCF[tei,text,tokens,sentences]->TEI,text,tokdata1 decoding

package DTA::TokWrap::Processor::tcfdecode;

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

## $dec = CLASS_OR_OBJ->new(%args)
##  + %args: (none)

## %defaults = CLASS_OR_OBJ->defaults()
##  + called by constructor
##  + inherited dummy method
#sub defaults { qw() }

## $dec = $dec->init()
##  + inherited dummy method
#sub init { $_[0] }

##==============================================================================
## Methods
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->tcfdecode($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    tcfdoc   => $tcfdoc,   ##-- (input) TCF input document
##    ##
##    tcfxdata => $tcfxdata, ##-- (output) TEI-XML decoded from TCF
##    tcftdata => $tcftdata, ##-- (output) text data decoded from TCF
##    tcfwdata => $tcfwdata, ##-- (output) tokenized data decoded from TCF, without byte-offsets, with "SID/WID" attributes
##    ##
##    tcfdecode_stamp0 => $f, ##-- (output) timestamp of operation begin
##    tcfdecode_stamp  => $f, ##-- (output) timestamp of operation end
##    tcfxdata_stamp   => $f, ##-- (output) timestamp of operation end
##    tcftdata_stamp   => $f, ##-- (output) timestamp of operation end
##    tcfwdata_stamp   => $f, ##-- (output) timestamp of operation end
## + code lifted in part from DTA::CAB::Format::TCF::parseDocument()
sub tcfdecode {
  my ($dec,$doc) = @_;
  $dec = $dec->new if (!ref($dec));
  $doc->setLogContext();

  ##-- log, stamp
  $dec->vlog($dec->{traceLevel},"tcfdecode()");
  $doc->{tcfdecode_stamp0} = timestamp(); ##-- stamp

  ##-- sanity check(s)
  $dec->logconfess("tcfdecode(): no {tcfdoc} defined") if (!$doc->{tcfdoc});

  ##-- decode: corpus: /D-Spin/TextCorpus
  my $xdoc    = $doc->{tcfdoc};
  my $xcorpus = $xdoc->findnodes('/*[local-name()="D-Spin"]/*[local-name()="TextCorpus"]')->[0]
    or $dec->logconfess("tcfdecode(): no /D-Spin/TextCorpus node found in TCF document");

  ##-- decode: xmldata: /D-Spin/TextCorpus/tei
  my $xtei = $xcorpus->findnodes('*[local-name()="tei"]')->[0];
  $doc->{tcfxdata} = $xtei ? $xtei->textContent : undef;
  utf8::encode($doc->{tcfxdata}) if (utf8::is_utf8($doc->{tcfxdata}));

  ##-- decode: txtdata: /D-Spin/TextCorpus/text
  my $xtext = $xcorpus->findnodes('*[local-name()="text"]')->[0];
  $doc->{tcftdata} = $xtext ? $xtext->textContent : undef;
  utf8::encode($doc->{tcftdata}) if (utf8::is_utf8($doc->{tcftdata}));

  ##-- parse: /D-Spin/TextCorpus/tokens
  my $xtokens = $xcorpus->findnodes('*[local-name()="tokens"]')->[0]
    or $dec->logconfess("tcfdecode(): no TextCorpus/tokens node found in TCF document");
  my (@wids,%id2w,$wid);
  foreach (@{$xtokens->findnodes('*[local-name()="token"]')}) {
    if (!defined($wid=$_->getAttribute('ID'))) {
      $wid = sprintf("w%x", $#wids);
      $_->setAttribute('ID'=>$wid);
    }
    $id2w{$wid} = $_->textContent;
    push(@wids,$wid);
  }

  ##-- parse: /D-Spin/TextCorpus/sentences
  my @sents = qw();
  my $xsents = $xcorpus->findnodes('*[local-name()="sentences"]')->[0];
  if (defined($xsents)) {
    my ($s,$sid,$swids);
    foreach (@{$xsents->findnodes('*[local-name()="sentence"]')}) {
      if (!defined($sid=$_->getAttribute('ID'))) {
	$sid = sprintf("s%x", $#sents);
	$_->setAttribute(ID=>$sid);
      }
      if (!defined($swids=$_->getAttribute('tokenIDs'))) {
	$dec->logwarn("tcfdecode(): no tokenIDs attribute for sentence #$sid, skipping");
	next;
      }
      push(@sents, [map {$id2w{$_}."\t$sid/$_\n"} split(' ',$swids)]);
    }
  } else {
    @sents = map {$id2w{$_}."\ts0/$_\n"} @wids;
  }

  ##-- decode: tcfwdata
  $doc->{tcfwdata} = join('', map {join('',@$_)."\n"} @sents);
  utf8::encode($doc->{tcfwdata}) if (utf8::is_utf8($doc->{tcfwdata}));

  ##-- finalize
  $doc->{tcfdecode_stamp} = $doc->{tcfxdata_stamp} = $doc->{tcftdata_stamp} = $doc->{tcfwdata_stamp} = timestamp(); ##-- stamp
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

DTA::TokWrap::Processor::tcfdecode - DTA tokenizer wrappers: TCF[tei,text,tokens,sentences]-E<gt>TEI,text decoding

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Processor::tcfdecode;
 
 $dec = DTA::TokWrap::Processor::tcfdecode->new(%opts);
 $doc_or_undef = $dec->tcfdecode($doc);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::TokWrap::Processor::tcfdecode provides an object-oriented
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor> wrapper
for decoding the C<tei>,C<text>,C<tokens>, and C<sentences> layers
of a tokenized TCF ("Text Corpus Format", cf. http://weblicht.sfs.uni-tuebingen.de/weblichtwiki/index.php/The_TCF_Format) document
as originally encoded by
a L<DTA::TokWrap::Processor::tcfencode|DTA::TokWrap::Processor::tcfencode> ("tcfencoder") object.
The encoded TCF document should have the following layers:

=over 4

=item tei

Source TEI-XML encoded as an XML text node; should be identical to the source XML
{xmlfile} or {xmldata} passed to the tcfencoder.

=item text

Serialized text encoded as an XML text node; should be identical to the serialized
text {txtfile} or {txtdata} passed to the tcfencoder.

=item tokens

Tokens returned by the tokenizer for the C<text> layer.
Document order of tokens should correspond B<exactly> to the serial order of the associated text in the C<text> layer.

=item sentences

Sentences returned by the tokenizer for the tokens in the C<tokens> layer.
Document order of sentences must correspond B<exactly> to the serial order of the associated text in the C<text> layer.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tcfdecode: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Processor::tcfdecode
inherits from
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tcfdecode: Constructors etc.
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
## DESCRIPTION: DTA::TokWrap::Processor::tcfdecode: Methods
=pod

=head2 Methods

=over 4

=item tcfdecode

 $doc_or_undef = $CLASS_OR_OBJECT->tcfdecode($doc);

Decodes the {tcfdoc} key of the
L<DTA::TokWrap::Document|DTA::TokWrap::Document> object
to TCF, storing the result in
C<$doc-E<gt>{tcfxdata}>, C<$doc-E<gt>{tcftdata}>, and C<$doc-E<gt>{tcfwdata}>.

Relevant %$doc keys:

 tcfdoc   => $tcfdoc,   ##-- (input) TCF input document
 ##
 tcfxdata => $tcfxdata, ##-- (output) TEI-XML decoded from TCF
 tcftdata => $tcftdata, ##-- (output) text data decoded from TCF
 tcfwdata => $tcfwdata, ##-- (output) tokenized data decoded from TCF, without byte-offsets, with "SID/WID" attributes
 ##
 tcfdecode_stamp0 => $f, ##-- (output) timestamp of operation begin
 tcfdecode_stamp  => $f, ##-- (output) timestamp of operation end
 tcfxdata_stamp   => $f, ##-- (output) timestamp of operation end
 tcftdata_stamp   => $f, ##-- (output) timestamp of operation end
 tcfwdata_stamp   => $f, ##-- (output) timestamp of operation end

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

Copyright (C) 2009-2014 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut


