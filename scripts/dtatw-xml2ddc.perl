#!/usr/bin/perl -w

use IO::File;
use XML::LibXML;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode encode_utf8 decode_utf8);
use File::Basename qw(basename);
#use Time::HiRes qw(gettimeofday tv_interval);
use Unicruft;
use Pod::Usage;

use strict;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);
our ($help);

##-- vars: I/O
our $xmlfile = undef;  ##-- required
our $outfile  = "-";   ##-- default: stdout

our $keep_blanks = 0;  ##-- keep input whitespace?
our $format = 1;       ##-- output format level

##-- field selection
our @fields = qw();
our @fields_default = ('@u','@t','@bb','@pb','@xr','@xc');
our $val_default = '-'; ##-- default field value for empty or undefined fields

##-- constants: verbosity levels
our $vl_warn     = 1;
our $vl_progress = 2;
our $verbose = $vl_progress;     ##-- print progress messages by default

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,
	   'verbose|v=i' => \$verbose,
	   'quiet|q' => sub { $verbose=!$_[1]; },

	   ##-- I/O
	   'keep-blanks|blanks|whitespace|ws!' => \$keep_blanks,
	   'index-field|index|i=s' => \@fields,
	   'output|out|o=s' => \$outfile,
	   'format|fmt!' => \$format,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);

##-- command-line: arguments
our $txmlfile = shift;
$txmlfile = '-' if (!$txmlfile);

@fields = @fields_default if (!@fields);

##======================================================================
## Subs: t-xml stuff (*.t.xml)

## $txmldoc = load_txml($txmlfile)
##  + loads and returns xml doc
sub load_txml {
  my $xmlfile = shift;

  ##-- initialize LibXML parser
  my $parser = XML::LibXML->new();
  $parser->keep_blanks($keep_blanks ? 1 : 0);
  $parser->line_numbers(1);

  ##-- load xml
  my $xdoc = $xmlfile eq '-' ? $parser->parse_fh(\*STDIN) : $parser->parse_file($xmlfile);
  die("$prog: could not parse .t.xml file '$xmlfile': $!") if (!$xdoc);

  ##-- ... and just return here
  return $xdoc;
}


##======================================================================
## MAIN

##-- grab .t.xml file into a libxml doc & pre-index some data
print STDERR "$prog: loading ddc-t-xml file '$txmlfile'...\n" if ($verbose>=$vl_progress);
my $indoc = load_txml($txmlfile);

##-- create output document
print STDERR "$prog: creating output document...\n" if ($verbose >= $vl_progress);
my $outdoc = XML::LibXML::Document->new("1.0","UTF-8");
my $outroot = XML::LibXML::Element->new("TEI");
$outdoc->setDocumentElement($outroot);

##-- populate output document: header

##-- populate output document: content
BEGIN { *isa=\&UNIVERSAL::isa; }
my $text = $outroot->addNewChild(undef,'text');
my $body = $text->addNewChild(undef,'body');
my ($s_in,$s_out, $w_in,$w_out, @wf);
foreach $s_in (@{$indoc->findnodes('//s')}) {
  $s_out = $body->addNewChild(undef,'s');
  foreach $w_in (@{$s_in->findnodes('w')}) {
    @wf = (
	   map {s/\s/_/g; $_}
	   map {utf8::is_utf8($_) ? $_ : decode_utf8($_)}
	   map {!defined($_) || $_ eq '' ? $val_default : $_}
	   map {isa($_,'XML::LibXML::Node') ? $_->textContent : $_}
	   map {isa($_,'XML::LibXML::Attr') ? $_->value : $_}
	   map {$w_in->findnodes($_)->[0]}
	   @fields
	  );
    $s_out->appendTextChild('l',join("\t", @wf));
  }
}

##-- dump
print STDERR "$prog: dumping output DDC file '$outfile'...\n"
  if ($verbose>=$vl_progress);
($outfile eq '-' ? $outdoc->toFH(\*STDOUT,$format) : $outdoc->toFile($outfile,$format))
  or die("$0: failed to write output DDC file '$outfile': $!");


__END__

=pod

=head1 NAME

dtatw-xml2ddc.perl - convert DTA::TokWrap ddc-t-xml files to DDC-parseable format

=head1 SYNOPSIS

 dtatw-xml2ddc.perl [OPTIONS] DDC_TXML_FILE

 General Options:
  -help                  # this help message
  -verbose LEVEL         # set verbosity level (0<=LEVEL<=1)
  -quiet                 # be silent

 I/O Options:
  -blanks , -noblanks    # do/don't keep 'ignorable' whitespace in DDC_TXML_FILE file (default=don't)
  -index XPATH           # set XPATH source for an output index field, relative to //w (overrides DTA defaults)
  -output FILE           # specify output file (default='-' (STDOUT))

=cut

##------------------------------------------------------------------------------
## Options and Arguments
##------------------------------------------------------------------------------
=pod

=head1 OPTIONS AND ARGUMENTS

Not yet written.

=cut

##------------------------------------------------------------------------------
## Description
##------------------------------------------------------------------------------
=pod

=head1 DESCRIPTION

Convert DTA::TokWrap .ddc.t.xml files to DDC XML format.

=cut

##------------------------------------------------------------------------------
## See Also
##------------------------------------------------------------------------------
=pod

=head1 SEE ALSO

L<dtatw-add-c.perl(1)|dtatw-add-c.perl>,
L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
L<dtatw-add-w.perl(1)|dtatw-add-w.perl>,
L<dtatw-add-s.perl(1)|dtatw-add-s.perl>,
L<dtatw-splice.perl(1)|dtatw-splice.perl>,
L<dtatw-rm-c.perl(1)|dtatw-rm-c.perl>,
...

=cut

##------------------------------------------------------------------------------
## Footer
##------------------------------------------------------------------------------
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=cut
