## -*- Mode: CPerl; coding: utf-8; -*-

## File: DTA::TokWrap::Processor::tok2xml.pm
## Author: Bryan Jurish <jurish@bbaw.de>
## Descript: DTA tokenizer wrappers: t -> t.xml, via dtatw-tok2xml

package DTA::TokWrap::Processor::tok2xml;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :files :slurp :time);
use DTA::TokWrap::Processor;

use IO::File;
use Carp;
use strict;
use utf8;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor);

##==============================================================================
## Constructors etc.
##==============================================================================

## $t2x = CLASS_OR_OBJ->new(%args)
## %defaults = CLASS->defaults()
##  + static class-dependent defaults
##  + %args, %defaults, %$t2x:
##    (
##    txmlsort => $bool,	     ##-- if true (default), sort output .t.xml data as close to input document-order as sentence boundaries will allow
##    t2x => $path_to_dtatw_tok2xml, ##-- default: search
##    b2xb => $path_to_dtatw_b2xb,   ##-- default: search; 'off' to disable
##    inplace => $bool,              ##-- prefer in-place programs for search?
##    )
sub defaults {
  my $that = shift;
  return (
	  ##-- inherited
	  $that->SUPER::defaults(),

	  ##-- sorting?
	  txmlsort => 1,

	  ##-- programs
	  t2x => undef,
	  b2xb => undef,
	  inplace => 1,
	 );
}

## $t2x = $t2x->init()
##  compute dynamic object-dependent defaults
sub init {
  my $t2x = shift;

  ##-- search for program(s)
  if (!defined($t2x->{t2x})) {
    $t2x->{t2x} = path_prog('dtatw-tok2xml',
			    prepend=>($t2x->{inplace} ? ['.','../src'] : undef),
			    warnsub=>sub {$t2x->logconfess(@_)},
			   );
  }

  if (!defined($t2x->{b2xb})) {
    $t2x->{b2xb} = path_prog('dtatw-b2xb',
			    prepend=>($t2x->{inplace} ? ['.','../src'] : undef),
			    warnsub=>sub {$t2x->logconfess(@_)},
			   );
  }

  return $t2x;
}

##==============================================================================
## Methods: Document Processing
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->tok2xml($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    tokfile1  => $tokfile1,  ##-- (input) tokenizer output file, must already be populated
##    cxfile    => $cxfile,    ##-- (input) character index file, must already be populated
##    bxfile    => $bxfile,    ##-- (input) block index data file, must already be populated
##    xtokdata  => $xtokdata,  ##-- (output) tokenizer output as XML (string)
##    tok2xml_stamp0 => $f,  ##-- (output) timestamp of operation begin
##    tok2xml_stamp  => $f,  ##-- (output) timestamp of operation end
##    xtokdata_stamp => $f,  ##-- (output) timestamp of operation end
sub tok2xml {
  my ($t2x,$doc) = @_;
  $doc->setLogContext();

  ##-- log, stamp
  $t2x->vlog($t2x->{traceLevel},"tok2xml()");
  $doc->{tok2xml_stamp0} = timestamp();

  ##-- sanity check(s)
  $t2x = $t2x->new() if (!ref($t2x));
  ##
  $t2x->logconfess("tok2xml(): no cxfile key defined") if (!$doc->{cxfile});
  $t2x->logconfess("tok2xml(): no bxfile key defined") if (!$doc->{bxfile});
  $t2x->logconfess("tok2xml(): no tokfile1 key defined") if (!$doc->{tokfile1});
  ##
  file_try_open($doc->{cxfile}) || $t2x->logconfess("tok2xml(): could not open .cx file '$doc->{cxfile}': $!");
  file_try_open($doc->{bxfile}) || $t2x->logconfess("tok2xml(): could not open .bx file '$doc->{bxfile}': $!");
  file_try_open($doc->{tokfile1}) || $t2x->logconfess("tok2xml(): could not open .t1 file '$doc->{tokfile1}': $!");

  ##-- run client program(s)
  my ($cmd);
  if ($t2x->{b2xb} ne 'off') {
    $t2x->vlog($t2x->{traceLevel},"command: $t2x->{b2xb} | $t2x->{t2x}");
    $cmd = "'$t2x->{b2xb}' '$doc->{tokfile1}' '$doc->{cxfile}' '$doc->{bxfile}' - | '$t2x->{t2x}' - - '$doc->{xmlbase}' |";
  } else {
    $t2x->vlog($t2x->{traceLevel},"command: $t2x->{t2x}");
    $cmd = "'$t2x->{t2x}' '$doc->{tokfile1}' - '$doc->{xmlbase}' |";
  }
  my $cmdfh = opencmd("$cmd")
    or $t2x->logconfess("tok2xml(): open failed for pipe '$t2x->{b2xb}'|'$t2x->{t2x}'|: $!");
  $doc->{xtokdata} = undef;
  slurp_fh($cmdfh,\$doc->{xtokdata});
  $cmdfh->close();

  ##-- re-sort?
  if ($t2x->{txmlsort}) {
    $t2x->vlog($t2x->{traceLevel},"sort (native)");
    my $data = \$doc->{xtokdata};
    my ($off,$len,$xb);
    my @s = qw();
    while ($$data =~ m{<s\b[^>]*>.*?</s>\s*}sg) {
      ($off,$len) = ($-[0],$+[0]-$-[0]);
      $xb = substr($$data, $off,$len) =~ m{<w[^>]*\bxb="([0-9]+)}s ? $1 : 1e38;
      push(@s,[$xb,$off,$len]);
    }
    my $prefix = substr($$data,0,$s[0][1]);
    my $suffix = substr($$data,$s[$#s][1]+$s[$#s][2]);
    my $sorted = $prefix.join('',map {substr($$data,$_->[1],$_->[2])} sort {$a->[0]<=>$b->[0]} @s).$suffix;
    $$data = $sorted;
  }

  ##-- finalize
  $doc->{tok2xml_stamp} = $doc->{xtokdata_stamp} = timestamp(); ##-- stamp
  return $doc;
}

1; ##-- be happy
__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Processor::tok2xml - DTA tokenizer wrappers: t -> t.xml

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Processor::tok2xml;
 
 $t2x = DTA::TokWrap::Processor::tok2xml->new(%opts);
 $doc_or_undef = $t2x->tok2xml($doc);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::TokWrap::Processor::tok2xml provides an object-oriented
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor> wrapper
for converting "raw" CSV-format (.t) low-level tokenizer output
to a "master" tokenized XML (.t.xml) format,
for use with L<DTA::TokWrap::Document|DTA::TokWrap::Document> objects.

Most users should use the high-level
L<DTA::TokWrap|DTA::TokWrap> wrapper class
instead of using this module directly.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tok2xml: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Processor::tok2xml
inherits from
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor>.

=item $NOC

Integer indicating a missing or implicit 'c' record;
should be equivalent in value to the C code:

 unsigned int NOC = ((unsigned int)-1)

for 32-bit "unsigned int"s.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tok2xml: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $t2x = $CLASS_OR_OBJECT->new(%args);

Constructor.

%args, %$t2x:

 ##-- output document structure
 docElt   => $elt,  ##-- output document element
 sElt     => $elt,  ##-- output sentence element
 wElt     => $elt,  ##-- output token element
 aElt     => $elt,  ##-- output token-analysis element
 posAttr  => $attr, ##-- output byte-position attribute
 textAttr => $attr, ##-- output token-text attribute

You probably should B<NOT> change any of the default output document
structure options (unless this is the final module in your
processing pipeline), since their values have ramifications beyond
this module.

=item defaults

 %defaults = CLASS->defaults();

Static class-dependent defaults.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tok2xml: Methods: tok2xml (bx0doc, txfile) => bxdata
=pod

=head2 Methods: tok2xml (bx0doc, txfile) => bxdata

=over 4

=item tok2xml

 $doc_or_undef = $CLASS_OR_OBJECT->tok2xml($doc);

Converts "raw" CSV-format (.t) low-level tokenizer output
to a "master" tokenized XML (.t.xml) format
in the
L<DTA::TokWrap::Document|DTA::TokWrap::Document> object
$doc.

Relevant %$doc keys:

 bxdata   => \@bxdata,   ##-- (input) block index data
 tokdata1  => $tokdata1, ##-- (input) tokenizer output data (string)
 cxdata   => \@cxchrs,   ##-- (input) character index data (array of arrays)
 cxfile   => $cxfile,    ##-- (input) character index file
 xtokdata => $xtokdata,  ##-- (output) tokenizer output as XML
 nchrs    => $nchrs,     ##-- (output) number of character index records
 ntoks    => $ntoks,     ##-- (output) number of tokens parsed
 ##
 tok2xml_stamp0 => $f,   ##-- (output) timestamp of operation begin
 tok2xml_stamp  => $f,   ##-- (output) timestamp of operation end
 xtokdata_stamp => $f,   ##-- (output) timestamp of operation end

$%t2x keys (temporary, for debugging):

 tb2ci   => $tb2ci,     ##-- (temp) s.t. vec($tb2ci, $txbyte, 32) = $char_index_of_txbyte
 ntb     => $ntb,       ##-- (temp) number of text bytes

may implicitly call $doc-E<gt>mkbx(), $doc-E<gt>loadCxFile(), $doc-E<gt>tokenize()
(but shouldn't!)

=item txbyte_to_ci

 \$tb2ci = $t2x->txbyte_to_ci(\@cxdata);

Low-level utility method.

Sets %$t2x keys: tb2ci, ntb, nchr

=item txtbyte_to_ci

 \$ob2ci = $t2x->txtbyte_to_ci(\@cxdata,\@bxdata,\$tb2ci);

Low-level utility method

Sets %$t2x keys: ob2ci

=item process_tt_data

 \$tokxmlr = $t2x->process_tt_data($doc);

Low-level utility method.

Actually populates $doc-E<gt>{xtokdata} by parsing $doc-E<gt>{tokdata1},
referring to $t2x-E<gt>{ob2ci} for character-index lookup.

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
