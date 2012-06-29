#!/usr/bin/perl -w

use IO::File;
use XML::LibXML;
use Getopt::Long qw(:config no_ignore_case);
use File::Basename qw(basename);
use POSIX; ##-- for strftime()
#use Date::Parse; ##-- for str2time()
#use Encode qw(encode decode encode_utf8 decode_utf8);
#use Time::HiRes qw(gettimeofday tv_interval);
#use Unicruft;
use Pod::Usage;

use strict;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);
our ($help);

##-- vars: I/O
our $infile  = undef;  ##-- required
our $basename = undef; ##-- default: basename($infile)
our $outfile = "-";   ##-- default: stdout

our $keep_blanks = 0;  ##-- keep input whitespace?
our $format = 1;       ##-- output format level

##-- constants: verbosity levels
our $vl_warn     = 1;
our $vl_progress = 2;
our $verbose = $vl_warn;

##-- globals: XML parser
our $parser = XML::LibXML->new();
$parser->keep_blanks($keep_blanks ? 1 : 0);
$parser->line_numbers(1);

*isa = \&UNIVERSAL::isa;

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,
	   'verbose|v=i' => \$verbose,
	   'quiet|q' => sub { $verbose=!$_[1]; },

	   ##-- I/O
	   'basename|base|b|dirname|dir|d=s' => \$basename,
	   'keep-blanks|blanks|whitespace|ws!' => \$keep_blanks,
	   'output|out|o=s' => \$outfile,
	   'format|fmt!' => \$format,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);

##-- command-line: arguments
$infile = shift;
$infile = '-' if (!$infile);

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
## X-Path utilities: get

## $nod = xpnod($root, $xpath)
sub xpnod {
  my ($root,$xp) = @_;
  return undef if (!ref($root));
  return $root->findnodes($xp)->[0];
}

## $val = xpval($root, $xpath)
sub xpval {
  my $nod = xpnod(@_);
  return undef if (!defined($nod));
  return isa($nod,'XML::LibXML::Attribute') ? $nod->nodeValue : $nod->textContent;
}

## $nod = xpgrepnod($root,@xpaths)
##  + returns 1st defined node for @xpaths
sub xpgrepnod {
  my $root = shift;
  my ($xp,$nod);
  foreach $xp (@_) {
    return $nod if (defined($nod = xpnod($root,$xp)));
  }
  return undef;
}

## $val = xpgrepval($root,@xpaths)
##  + returns 1st defined value for @xpaths
sub xpgrepval {
  my $root = shift;
  my ($xp,$val);
  foreach $xp (@_) {
    return $val if (defined($val = xpval($root,$xp)));
  }
  return undef;
}

##======================================================================
## X-Path utilities: ensure

## \@xpspec = parse_xpath($xpath)
##  + handles basic xpaths only (/ELT or /ELT[@ATTR="VAL"])
sub parse_xpath {
  my $path = shift;
  return [
	  map {m/^([^\[\s]+)\[\s*\@([^\=\s]+)\s*=\s*\"([^\"\s]*)\"\s*\]/ ? [$1,$2=>$3] : $_}
	  grep {defined($_) && $_ ne ''}
	  split(/\//, $path)
	 ];
}

## $xpath_str = unparse_xpath(\@xpspec)
sub unparse_xpath {
  my ($elt,%attrs);
  return $_[0] if (!ref($_[0]));
  return join('/',
	      map {
		($elt,%attrs) = UNIVERSAL::isa($_,'ARRAY') ? (@$_) : ($_);
		"$elt\[".join(' and ', map {"\$_=\"$attrs{$_}\""} sort keys %attrs)."]"
	      } @{$_[0]});
}

## $node          = get_xpath($root,\@xpspec_or_xpath)      ##-- scalar context
## ($node,$isnew) = get_xpath($root,\@xpspec_or_xpath)      ##-- array context
##  + gets or creates node corresponding to \@xpspec_or_xpath
##  + each \@xpspec element is either
##    - a SCALAR ($tagname), or
##    - an ARRAY [$tagname, %attrs ]
sub get_xpath {
  my ($root,$xpspec) = @_;
  $xpspec = parse_xpath($xpspec) if (!ref($xpspec));
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
## $nod = ensure_xpath($root,\@xpspec,$default_value,$warn_if_missing)
sub ensure_xpath {
  my ($root,$xpspec,$val,$warn_if_missing) = @_;
  my ($elt,$isnew) = get_xpath($root, $xpspec);
  if ($isnew) {
    warn("$prog: $basename: missing XPath ".unparse_xpath($xpspec)." defaults to \"".($val||'')."\"")
      if ($warn_if_missing && $verbose >= $vl_warn);
    $elt->appendText($val) if (defined($val));
    $elt->parentNode->insertAfter(XML::LibXML::Comment->new("/".$elt->nodeName.": added by $prog"), $elt);
  }
  return $elt;
}

##======================================================================
## MAIN

##-- grab header file
my $hdoc = loadxml($infile);
my $hroot = $hdoc->documentElement;
$hroot = get_xpath($hroot) if ($hroot->nodeName ne 'teiHeader');

##-- default: basename
$basename = basename($infile) if (!defined($basename));
$basename =~ s/\..*$//;

##-- meta: author
my @author_xpaths = (
		     'fileDesc/titleStmt/author[@n="ddc"]', ##-- new (formatted)
		     'fileDesc/titleStmt/author', ##-- new (un-formatted)
		     'fileDesc/sourceDesc/listPerson[@type="searchNames"]/person/persName', ##-- old
		    );
my $author_nod = xpgrepnod($hroot,@author_xpaths);
my ($author);
if ($author_nod && $author_nod->nodeName eq 'persName') {
  ##-- parse pre-formatted author node (old, pre-2012-07)
  $author = $author_nod->textContent;
  warn("$prog: $basename: using obsolete author node ", $author_nod->nodePath);
}
elsif ($author_nod && $author_nod->nodeName eq 'author' && ($author_nod->getAttribute('n')||'') ne 'ddc') {
  warn("$prog: $basename: formatting author node from ", $author_nod->nodePath) if ($verbose >= $vl_progress);
  ##-- parse structured author node (new, 2012-07)
  my ($nnods,$first,$last,@other,$name);
  $author = join('; ',
		 map {
		   $last  = xpval($_,'surname');
		   $first = xpval($_,'forename');
		   @other = (
			     ($_->hasAttribute('key') ? $_->getAttribute('key') : qw()),
			     map {
			       ($_->nodeName eq 'name' && $_->hasAttribute('key') ? $_->getAttribute('key')
				: ($_->nodeName eq 'idno' ? (($_->getAttribute('type')||'idno').":".$_->textContent)
				   : $_->textContent))
			     }
			     grep {$_->nodeName !~ /^(?:sur|fore)name$/}
			     @{$_->findnodes('*')}
			    );
		   $name = "$last, $first (".join('; ', @other).")";
		   $name =~ s/^, //;
		   $name =~ s/ \(\)//;
		   $name
		 }
		 map {
		   $nnods = $_->findnodes('name');
		   ($nnods && @$nnods ? @$nnods : $_)
		 }
		 @{$hroot->findnodes('fileDesc/titleStmt/author')});
}
if (!defined($author)) {
  ##-- guess author from basename
  warn("$prog: $basename: missing author XPath(s) ", join('|', @author_xpaths)) if ($verbose >= $vl_warn);
  $author = ($basename =~ m/^([^_]+)_/ ? $1 : '');
  $author =~ s/\b([[:lower:]])/\U$1/g; ##-- implicitly upper-case
}
ensure_xpath($hroot, 'fileDesc/titleStmt/author[@n="ddc"]', $author);

##-- meta: title
my $title = ($basename =~ m/^[^_]+_([^_]+)_/ ? ucfirst($1) : '');
ensure_xpath($hroot, 'fileDesc/titleStmt/title', $title, 1);

##-- meta: date
my @date_xpaths = (
		   'fileDesc/sourceDesc[@n="orig"]/biblFull/publicationStmt/date', ##-- old:firstDate
		   'fileDesc/sourceDesc[@n="scan"]/biblFull/publicationStmt/date', ##-- old:publDate
		   'fileDesc/sourceDesc/biblFull/publicationStmt/date', ##-- new:date
		  );
my $date = xpgrepval($hroot,@date_xpaths);
if (!$date) {
  $date = ($basename =~ m/^[^\.]*_([0-9]+)$/ ? $1 : 0);
  warn("$prog: $basename: missing date XPpath $date_xpaths[$#date_xpaths] defaults to \"$date\"") if ($verbose >= $vl_warn);
}
ensure_xpath($hroot, 'fileDesc/sourceDesc[@n="orig"]/biblFull/publicationStmt/date[@type="first"]', $date); ##-- old (<2012-07)
ensure_xpath($hroot, 'fileDesc/sourceDesc[@n="ddc"]/biblFull/publicationStmt/date', $date);  ##-- new (>=2012-07)

##-- meta: bibl
my @bibl_xpaths = (
		   'fileDesc/sourceDesc[@n="ddc"]/bibl', ##-- new:canonical
		   'fileDesc/sourceDesc[@n="orig"]/bibl', ##-- old:firstBibl
		   'fileDesc/sourceDesc[@n="scan"]/bibl', ##-- old:publBibl
		   'fileDesc/sourceDesc/bibl', ##-- new|old:generic
		   );
my $bibl = xpgrepval($hroot,@bibl_xpaths);
if (!defined($bibl)) {
  $bibl = "$author: $title. $date";
  warn("$prog: $basename: missing bibl XPath(s) ".join('|',@bibl_xpaths)) if ($verbose >= $vl_warn);
}
ensure_xpath($hroot, 'fileDesc/sourceDesc[@n="orig"]/bibl', $bibl); ##-- old (<2012-07)
ensure_xpath($hroot, 'fileDesc/sourceDesc[@n="ddc"]/bibl', $bibl); ##-- new (>=2012-07)

##-- meta: shelfmark
my @shelfmark_xpaths = ('fileDesc/sourceDesc/msDesc/msIdentifier/idno[@type="shelfmark"]', ##-- new (>=2012-07)
			'fileDesc/sourceDesc/biblFull/notesStmt/note[@type="location"]/ident[@type="shelfmark"]', ##-- old (<2012-07)
		       );
my $shelfmark = xpgrepval($hroot,@shelfmark_xpaths);
ensure_xpath($hroot, $shelfmark_xpaths[$_], $shelfmark, ($_==0)) foreach (0..$#shelfmark_xpaths);

##-- meta: library
my @library_xpaths = ('fileDesc/sourceDesc/msDesc/msIdentifier/repository', ##-- new
		      'fileDesc/sourceDesc/biblFull/notesStmt/note[@type="location"]/name[@type="repository"]', ##-- old
		     );
my $library = xpgrepval($hroot, @library_xpaths);
ensure_xpath($hroot, $library_xpaths[$_], $library, ($_==0)) foreach (0..$#library_xpaths);

##-- meta: dtadir
my @dirname_xpaths = ('fileDesc/publicationStmt/idno[@type="DTADIR"]', ##-- old (<2012-07)
		      'fileDesc/publicationStmt/idno[@type="DTADIRNAME"]', ##-- new (>=2012-07)
		     );
my $dirname = xpgrepval($hroot,@dirname_xpaths) || $basename;
ensure_xpath($hroot,$dirname_xpaths[$_],$dirname,($_==1)) foreach (0..$#dirname_xpaths);

##-- meta: timestamp: ISO
my $timestamp_xpath = 'fileDesc/publicationStmt/date';
my $timestamp = xpval($timestamp_xpath);
if (!$timestamp) {
  my $time = $infile eq '-' ? time() : (stat($infile))[9];
  $timestamp = POSIX::strftime("%FT%H:%M:%SZ",gmtime($time));
  ensure_xpath($hroot,$timestamp_xpath,$timestamp,1);
}

##-- dump
($outfile eq '-' ? $hdoc->toFH(\*STDOUT,$format) : $hdoc->toFile($outfile,$format))
  or die("$0: failed to write output file '$outfile': $!");


__END__

=pod

=head1 NAME

dtatw-sanitize-header.perl - make DDC/DTA-friendly TEI-headers

=head1 SYNOPSIS

 dtatw-sanitize-header.perl [OPTIONS] XML_HEADER_FILE

 General Options:
  -help                  # this help message
  -verbose LEVEL         # set verbosity level (0<=LEVEL<=1)
  -quiet                 # be silent

 I/O Options:
  -blanks , -noblanks    # do/don't keep 'ignorable' whitespace in DDC_TXML_FILE file (default=don't)
  -base BASENAME	 # use BASENAME to auto-compute field names (default=basename(XML_HEADER_FILE))
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

Ensure DDC/DTA-friendly TEI headers.

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
