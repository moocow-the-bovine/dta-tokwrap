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
our $headfile = undef; ##-- default: none
our $outfile  = "-";   ##-- default: stdout

our $keep_blanks = 0;  ##-- keep input whitespace?
our $add_dtadir  = 1;  ##-- add 'dtadir' idno to header if not already present?
our $add_date = 1;     ##-- add 'date' field to header if not already present?
our $format = 1;       ##-- output format level

##-- field selection
our @fields = qw();
our @fields_default = ('@u','@t','@bb','@pb','@xr','@xc');
our $val_default = '-'; ##-- default field value for empty or undefined fields

##-- constants: verbosity levels
our $vl_warn     = 1;
our $vl_progress = 2;
our $verbose = $vl_progress;     ##-- print progress messages by default

##-- globals: XML parser
our $parser = XML::LibXML->new();
$parser->keep_blanks($keep_blanks ? 1 : 0);
$parser->line_numbers(1);

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,
	   'verbose|v=i' => \$verbose,
	   'quiet|q' => sub { $verbose=!$_[1]; },

	   ##-- I/O
	   'keep-blanks|blanks|whitespace|ws!' => \$keep_blanks,
	   'header-file|hf=s' => \$headfile,
	   'dtadir|dirname|dir!' => \$add_dtadir,
	   'date!' => \$add_date,
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

## $xmldoc = loadxml($xmlfile)
##  + loads and returns xml doc
sub loadxml {
  my $xmlfile = shift;
  my $xdoc = $xmlfile eq '-' ? $parser->parse_fh(\*STDIN) : $parser->parse_file($xmlfile);
  die("$prog: could not parse XML file '$xmlfile': $!") if (!$xdoc);
  return $xdoc;
}

##======================================================================
## X-Path utilities

## $node          = get_xpath($root,\@xpspec)      ##-- scalar context
## ($node,$isnew) = get_xpath($root,\@xpspec)      ##-- array context
##  + gets or creates node corresponding to \@xpspec
##  + each \@xpspec element is either
##    - a SCALAR ($tagname), or
##    - an ARRAY [$tagname, %attrs ]
sub get_xpath {
  my ($root,$xpspec) = @_;
  my ($step,$xp,$tag,%attrs,$next);
  my $isnew = 0;
  foreach $step (@$xpspec) {
    ($tag,%attrs) = ref($step) ? @$step : ($step);
    $xp = $tag;
    $xp .= "[".join(' and ', map {"\@$_='$attrs{$_}'"} sort keys %attrs)."]" if (%attrs);
    if (!defined($next = $root->findnodes($xp)->[0])) {
      $next = $root->addNewChild(undef,$tag);
      $next->setAttribute($_,$attrs{$_}) foreach (sort keys %attrs);
      $isnew = 1;
    }
    $root = $next;
  }
  return wantarray ? ($root,$isnew) : $root;
}

## $nod = ensure_xpath($root,\@xpspec,$default_value)
sub ensure_xpath {
  my ($root,$xpspec,$val) = @_;
  my ($elt,$isnew) = get_xpath($root, $xpspec);
  if ($isnew) {
    $elt->appendText($val);
    $elt->appendChild(XML::LibXML::Comment->new("added by $prog"));
  }
  return $elt;
}

##======================================================================
## MAIN

##-- grab .t.xml file into a libxml doc
print STDERR "$prog: loading ddc-t-xml file '$txmlfile'...\n" if ($verbose>=$vl_progress);
my $indoc = loadxml($txmlfile);

##-- grab header file
my ($headdoc);
if (defined($headfile)) {
  print STDERR "$prog: loading header XML file '$headfile'...\n" if ($verbose>=$vl_progress);
  $headdoc = loadxml($headfile)
}

##-- create output document
print STDERR "$prog: creating output document...\n" if ($verbose >= $vl_progress);
my $outdoc  = XML::LibXML::Document->new("1.0","UTF-8");
my $outroot = XML::LibXML::Element->new("TEI");
$outdoc->setDocumentElement($outroot);

##-- populate output document: header
if ($headdoc) {
  $outroot->appendChild( $headdoc->documentElement->cloneNode(1) );
}

##==========================================================
## BEGIN OBSOLETE STUFF: this can go when dta2012 goes live

##-- header: metadata: dtadir
if ($add_dtadir) {
  (my $dirname = basename($txmlfile)) =~ s/\..*$//;
  ensure_xpath($outroot, [qw(teiHeader fileDesc publicationStmt), ['idno', type=>"DTADIR"]],     $dirname); ##-- old (<2012-07)
  ensure_xpath($outroot, [qw(teiHeader fileDesc publicationStmt), ['idno', type=>"DTADIRNAME"]], $dirname); ##-- new (>=2012-07)
}
##-- header: metadata: date
if ($add_date) {
  my $date = basename($txmlfile) =~ m/^[^\.]*_([0-9]+)\./ ? $1 : 0;
  #ensure_xpath($outroot, [qw(teiHeader fileDesc), ['sourceDesc',n=>"orig"], qw(biblFull publicationStmt), ['date',type=>"first"]], $date); ##-- old (<2012-07)
  #ensure_xpath($outroot, [qw(teiHeader fileDesc    sourceDesc                 biblFull publicationStmt     date)], $date);                 ##-- new (>=2012-07)
  ##
  ensure_xpath($outroot, [qw(teiHeader fileDesc), ['sourceDesc',n=>"orig"], qw(biblFull publicationStmt), ['date',type=>"first"]], $date); ##-- old|new (<=>2012-07)
}

## END OBSOLETE STUFF
##==========================================================

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
  -header HEADERFILE     # splice in teiHeader from HEADERFILE (default=none)
  -dtadir , -nodtadir    # do/don't add an <idno type="dtadir"> if not already present (default=do)
  -date   , -nodate      # do/don't add an <idno type="dtadir"> if not already present (default=do)
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
