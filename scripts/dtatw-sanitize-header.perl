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
  die("$prog: ERROR: could not parse XML file '$xmlfile': $!") if (!$xdoc);
  return $xdoc;
}

##======================================================================
## X-Path utilities: get

## \@nods = xpnods($root, $xpath)
sub xpnods {
  my ($root,$xp) = @_;
  return undef if (!ref($root));
  return $root->findnodes($xp);
}

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
    warn("$prog: $basename: WARNING: missing XPath ".unparse_xpath($xpspec)." defaults to \"".($val||'')."\"")
      if ($warn_if_missing && $verbose >= $vl_warn);
    $elt->appendText($val) if (defined($val));
    $elt->parentNode->insertAfter(XML::LibXML::Comment->new("/".$elt->nodeName.": added by $prog"), $elt);
  }
  return $elt;
}

##======================================================================
## MAIN

##-- default: basename
$basename = basename($infile) if (!defined($basename));
$basename =~ s/\..*$//;

##-- grab header file
my $hdoc = loadxml($infile);
my $hroot = $hdoc->documentElement;
if ($hroot->nodeName ne 'teiHeader') {
  die("$prog: $infile ($basename): ERROR: no //teiHeader element found")
    if (!defined($hroot=$hroot->findnodes('(//teiHeader)[1]')->[0]));
}

##-- meta: author
my @author_xpaths = (
		     'fileDesc/titleStmt/author[@n="ddc"]',							##-- new (formatted)
		     'fileDesc/titleStmt/author',								##-- new (direct, un-formatted)
		     'fileDesc/sourceDesc/biblFull/titleStmt/author',						##-- new (sourceDesc, un-formatted)
		     'fileDesc/titleStmt/editor[string(@corresp)!="#DTACorpusPublisher"]',   			##-- new (direct, un-formatted)
		     'fileDesc/sourceDesc/biblFull/titleStmt/editor[string(@corresp)!="#DTACorpusPublisher"]',	##-- new (sourceDesc, un-formatted)
		     'fileDesc/sourceDesc/listPerson[@type="searchNames"]/person/persName',			##-- old
		    );
my $author_nod = xpgrepnod($hroot,@author_xpaths);
my ($author);
if ($author_nod && $author_nod->nodeName eq 'persName') {
  ##-- parse pre-formatted author node (old, pre-2012-07)
  $author = $author_nod->textContent;
  warn("$prog: $basename: WARNING: using obsolete author node ", $author_nod->nodePath);
}
elsif ($author_nod && $author_nod->nodeName eq 'author' && ($author_nod->getAttribute('n')||'') eq 'ddc') {
  ##-- ddc-author node: direct from document
  $author = $author_nod->textContent;
}
elsif ($author_nod && $author_nod->nodeName =~ /^(?:author|editor)$/ && ($author_nod->getAttribute('n')||'') ne 'ddc') {
  warn("$prog: $basename: WARNING: formatting author node from ", $author_nod->nodePath) if ($verbose >= $vl_progress);
  ##-- parse structured author node (new, 2012-07)
  my ($nnods,$first,$last,$gen,@other,$name);
  $author = join('; ',
		 map {
		   $last  = xpval($_,'surname');
		   $first = xpval($_,'forename');
		   $gen   = xpval($_,'genName');
		   @other = (
			     (map {$_->textContent} @{$_->findnodes('addName')}), #|roleName e.g. "König von Preußen" beim alten Fritz (http://d-nb.info/gnd/118535749)
			     ($_->hasAttribute('ref') ? $_->getAttribute('ref') : qw()),
			     ($_->nodeName eq 'editor' || $_->parentNode->nodeName eq 'editor' ? 'ed.' : qw()),
			    );
		   $_ =~ s{^http://d-nb.info/gnd/}{#}g foreach (@other); ##-- pnd hack
		   $name = ($last||'').", ".($first||'').($gen ? " $gen" : '').' ('.join('; ', @other).')';
		   $name =~ s/^, //;
		   $name =~ s/ \(\)//;
		   $name
		 }
		 map {
		   $nnods = $_->findnodes('name|persName');
		   ($nnods && @$nnods ? @$nnods : $_)
		 }
		 @{$author_nod->findnodes('../'.$author_nod->nodeName.'[string(@corresp)!="#DTACorpusPublisher"]')});
}
if (!defined($author)) {
  ##-- guess author from basename
  warn("$prog: $basename: WARNING: missing author XPath(s) ", join('|', @author_xpaths)) if ($verbose >= $vl_warn);
  $author = ($basename =~ m/^([^_]+)_/ ? $1 : '');
  $author =~ s/\b([[:lower:]])/\U$1/g; ##-- implicitly upper-case
}
ensure_xpath($hroot, 'fileDesc/titleStmt/author[@n="ddc"]', $author);

##-- meta: title
my $title       = ($basename =~ m/^[^_]+_([^_]+)_/ ? ucfirst($1) : '');
my $title_xpath = 'fileDesc/titleStmt/title[@type="main" or @type="sub" or @type="vol"]';
my $title_nods  = $hroot->findnodes($title_xpath);
if (@$title_nods) {
  $title  = join(' / ', map {$_->textContent} grep {$_->getAttribute('type') eq 'main'} @$title_nods);
  $title .= join('', map {": ".$_->textContent} grep {$_->getAttribute('type') eq 'sub'} @$title_nods);
  $title .= join('', map {" (".($_->textContent =~ m/\S/ ? $_->textContent : ($_->getAttribute('n')||'?')).")"} grep {$_->getAttribute('type') eq 'vol'} @$title_nods);
  $title =~ s/\s+/ /g;
  $title =~ s/^ //;
  $title =~ s/ $//;
} else {
  warn("$prog: $basename: WARNING: missing title XPath(s) $title_xpath defaults to '$title'") if ($verbose >= $vl_warn);
}
ensure_xpath($hroot, 'fileDesc/titleStmt/title[@type="ddc"]', $title, 0);

##-- meta: date (published)
my @date_xpaths = (
		   'fileDesc/sourceDesc[@n="ddc"]/biblFull/publicationStmt/date[@type="pub"]', ##-- ddc
		   'fileDesc/sourceDesc[@n="scan"]/biblFull/publicationStmt/date', ##-- old:publDate
		   'fileDesc/sourceDesc/biblFull/publicationStmt/date[@type="publication"]/supplied', ##-- new:date (published, supplied)
		   'fileDesc/sourceDesc/biblFull/publicationStmt/date[@type="publication"]', ##-- new:date (published)
		   'fileDesc/sourceDesc/biblFull/publicationStmt/date/supplied', ##-- new:date (generic, supplied)
		   'fileDesc/sourceDesc/biblFull/publicationStmt/date', ##-- new:date (generic, supplied)
		  );
my $date = xpgrepval($hroot,@date_xpaths);
if (!$date) {
  $date = ($basename =~ m/^[^\.]*_([0-9]+)$/ ? $1 : 0);
  warn("$prog: $basename: WARNING: missing date XPath $date_xpaths[$#date_xpaths] defaults to \"$date\"") if ($verbose >= $vl_warn);
}
#ensure_xpath($hroot, 'fileDesc/sourceDesc[@n="scan"]/biblFull/publicationStmt/date[@type="first"]', $date); ##-- old (<2012-07)
ensure_xpath($hroot, 'fileDesc/sourceDesc[@n="ddc"]/biblFull/publicationStmt/date[@type="pub"]', $date);  ##-- new (>=2012-07)

##-- meta: date (first)
foreach (@date_xpaths) {
  s/="scan"/="orig"/;
  s/="publication"/="firstPublication"/;
  s/="pub"/="first"/;
}
my $date1 = xpgrepval($hroot,@date_xpaths);
if (!$date1) {
  $date1 = $date;
  warn("$prog: $basename: WARNING: missing original-date XPath $date_xpaths[$#date_xpaths] defaults to \"$date1\"") if (0 && $verbose >= $vl_warn);
}
#ensure_xpath($hroot, 'fileDesc/sourceDesc[@n="orig"]/biblFull/publicationStmt/date[@type="first"]', $date1); ##-- old (<2012-07)
ensure_xpath($hroot, 'fileDesc/sourceDesc[@n="ddc"]/biblFull/publicationStmt/date[@type="first"]', $date1);  ##-- new (>=2012-11)

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
  warn("$prog: $basename: WARNING: missing bibl XPath(s) ".join('|',@bibl_xpaths)) if ($verbose >= $vl_warn);
}
ensure_xpath($hroot, 'fileDesc/sourceDesc[@n="orig"]/bibl', $bibl); ##-- old (<2012-07)
ensure_xpath($hroot, 'fileDesc/sourceDesc[@n="ddc"]/bibl', $bibl); ##-- new (>=2012-07)

##-- meta: shelfmark
my @shelfmark_xpaths = (
			'fileDesc/sourceDesc[@n="ddc"]/msDesc/msIdentifier/idno[@type="shelfmark"]', ##-- new:canonical
			'fileDesc/sourceDesc/msDesc/msIdentifier/idno[@type="shelfmark"]', ##-- new (>=2012-07)
			'fileDesc/sourceDesc/biblFull/notesStmt/note[@type="location"]/ident[@type="shelfmark"]', ##-- old (<2012-07)
		       );
my $shelfmark = xpgrepval($hroot,@shelfmark_xpaths) || '-';
ensure_xpath($hroot, $shelfmark_xpaths[0], $shelfmark, 0);

##-- meta: library
my @library_xpaths = (
		      'fileDesc/sourceDesc[@n="ddc"]/msDesc/msIdentifier/repository', ##-- new:canonical
		      'fileDesc/sourceDesc/msDesc/msIdentifier/repository', ##-- new
		      'fileDesc/sourceDesc/biblFull/notesStmt/note[@type="location"]/name[@type="repository"]', ##-- old
		     );
my $library = xpgrepval($hroot, @library_xpaths) || '-';
ensure_xpath($hroot, $library_xpaths[0], $library, 0);

##-- meta: dtadir
my @dirname_xpaths = ('fileDesc/publicationStmt/idno[@type="DTADirName"]', ##-- newer(?) (>=2012-09)
		      'fileDesc/publicationStmt/idno[@type="DTADIRNAME"]', ##-- new (>=2012-07)
		      'fileDesc/publicationStmt/idno[@type="DTADIR"]',     ##-- old (<2012-07)
		     );
my $dirname = xpgrepval($hroot,@dirname_xpaths) || $basename;
ensure_xpath($hroot,$dirname_xpaths[0],$dirname,1);

##-- meta: dtaid
my @dtaid_xpaths = ('fileDesc/publicationStmt/idno[@type="DTAID"]',
		   );
my $dtaid = xpgrepval($hroot,@dtaid_xpaths) || "0";
ensure_xpath($hroot,$dtaid_xpaths[0],$dtaid,1);

##-- meta: timestamp: ISO
my $timestamp_xpath = 'fileDesc/publicationStmt/date';
my $timestamp = xpval($timestamp_xpath);
if (!$timestamp) {
  my $time = $infile eq '-' ? time() : (stat($infile))[9];
  $timestamp = POSIX::strftime("%FT%H:%M:%SZ",gmtime($time));
  ensure_xpath($hroot,$timestamp_xpath,$timestamp,1);
}

##-- meta: availability (text)
my @avail_xpaths = (
		    'fileDesc/publicationStmt/availability[@type="ddc"]',
		    'fileDesc/publicationStmt/availability',
		   );
my $avail       = xpgrepval($hroot,@avail_xpaths) || "-";
ensure_xpath($hroot, $avail_xpaths[0], $avail, 0);

##-- meta: text-class: dta
my $tcdta = join('::',
		 map {$_->textContent}
		 @{xpnods($hroot,join('|',
				      'profileDesc/textClass/classCode[@scheme="http://www.deutschestextarchiv.de/doku/klassifikation#dtamain"]',
				      'profileDesc/textClass/classCode[@scheme="http://www.deutschestextarchiv.de/doku/klassifikation#dtasub"]'))}
		);
ensure_xpath($hroot, 'profileDesc/textClass/classCode[@scheme="ddcTextClassDTA"]', ($tcdta||''), 0);

##-- meta: text-class: dwds
my $tcdwds = join('::',
		  map {$_->textContent}
		  @{xpnods($hroot,join('|',
				       'profileDesc/textClass/classCode[@scheme="http://www.deutschestextarchiv.de/doku/klassifikation#dwds1main"]',
				       'profileDesc/textClass/classCode[@scheme="http://www.deutschestextarchiv.de/doku/klassifikation#dwds1sub"]',
				       'profileDesc/textClass/classCode[@scheme="http://www.deutschestextarchiv.de/doku/klassifikation#dwds2main"]',
				       'profileDesc/textClass/classCode[@scheme="http://www.deutschestextarchiv.de/doku/klassifikation#dwds2sub"]',))}
		 );
ensure_xpath($hroot, 'profileDesc/textClass/classCode[@scheme="ddcTextClassDWDS"]', ($tcdwds||''), 0);

##-- meta: text-class: dta-corpus (ocr|mts|cn|...)
my $tccorpus = join('::',
		    map {$_->textContent}
		    @{xpnods($hroot,join('|',
					 'profileDesc/textClass/classCode[@scheme="http://www.deutschestextarchiv.de/doku/klassifikation#DTACorpus"]'))}
		   );
ensure_xpath($hroot, 'profileDesc/textClass/classCode[@scheme="ddcTextClassCorpus"]', ($tccorpus||''), 0);

##-- dump
($outfile eq '-' ? $hdoc->toFH(\*STDOUT,$format) : $hdoc->toFile($outfile,$format))
  or die("$0: ERROR: failed to write output file '$outfile': $!");


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
L<dtatw-add-ws.perl(1)|dtatw-add-ws.perl>,
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
