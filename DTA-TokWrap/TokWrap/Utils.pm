## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Utils.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA tokenizer wrappers: miscellaneous utilities

package DTA::TokWrap::Utils;
use DTA::TokWrap::Version;
use DTA::TokWrap::Logger;
use Env::Path;
use XML::LibXML;
use XML::LibXSLT;
use Time::HiRes;
use File::Basename qw(basename dirname);
use Cwd; ##-- for abs_path()
use IO::File;
use Exporter;
use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(Exporter DTA::TokWrap::Logger);

our @EXPORT = qw();
our %EXPORT_TAGS = (
		    files => [qw(file_mtime file_is_newer  file_try_open abs_path str2file ref2file)],
		    slurp => [qw(slurp_file slurp_fh)],
		    progs => ['path_prog','runcmd','opencmd','$TRACE_RUNCMD'],
		    libxml => [qw(libxml_parser)],
		    libxslt => [qw(xsl_stylesheet)],
		    time => [qw(timestamp)],
		    si => [qw(sistr)],
		   );
$EXPORT_TAGS{all} = [map {@$_} values(%EXPORT_TAGS)];
our @EXPORT_OK = @{$EXPORT_TAGS{all}};


## $TRACE_RUNCMD = $level
##  + log-level for tracing runcmd() calls
#our $TRACE_RUNCMD = 'trace';
our $TRACE_RUNCMD = undef;

##==============================================================================
## Utils: external programs

## $progpath_or_undef = PACKAGE::path_prog($progname,%opts)
##  + %opts:
##    prepend => \@paths,  ##-- prepend @paths to Env::Path->PATH->List
##    append  => \@paths,  ##-- append @paths to Env::Path->PATH->List
##    warnsub => \&sub,    ##-- warn subroutine if path not found (undef for no warnings);
sub path_prog {
  my ($prog,%opts) = @_;
  return $prog if ($prog =~ /^[\.\/]/ && -x $prog); ##-- detect fully specified paths
  my @paths = Env::Path->PATH->List;
  unshift(@paths, @{$opts{prepend}}) if ($opts{prepend});
  push   (@paths, @{$opts{append}} ) if ($opts{append});
  foreach (@paths) {
    return "$_/$prog" if (-x "$_/$prog");
  }
  $opts{warnsub}->(__PACKAGE__, "::path_prog(): could not find program '$prog' in path (", join(' ', @paths), ")")
    if ($opts{warnsub});
  return undef;
}

## $system_rc = PACKAGE::runcmd(@cmd)
sub runcmd {
  my @argv = @_;
  __PACKAGE__->vlog($TRACE_RUNCMD,"runcmd(): ", join(' ', map {$_=~/\s/ ? "\"$_\"" : $_} @argv))
    if ($TRACE_RUNCMD);
  return system(@argv);
}

## $fh_or_undef = PACKAGE::opencmd($cmd)
##  + does log trace at level $TRACE_RUNCMD
sub opencmd {
  my $cmd = shift;
  __PACKAGE__->vlog($TRACE_RUNCMD,"opencmd(): ", $cmd) if ($TRACE_RUNCMD);
  return IO::File->new($cmd);
}

##==============================================================================
## Utils: XML::LibXML
##==============================================================================

## %LIBXML_PARSERS
##  + XML::LibXML parsers, keyed by parser attribute strings (see libxml_parser())
our %LIBXML_PARSERS = qw();

## $parser = libxml_parser(%opts)
##  + %opts:
##     line_numbers => $bool,  ##-- default: 1
##     load_ext_dtd => $bool,  ##-- default: 0
##     validation   => $bool,  ##-- default: 0
##     keep_blanks  => $bool,  ##-- default: 1
##     expand_entities => $bool, ##-- default: 1
##     recover => $bool,         ##-- default: 1
sub libxml_parser {
  my %opts = @_;
  my %defaults = (
		  line_numbers => 1,
		  load_ext_dtd => 0,
		  validation => 0,
		  keep_blanks => 1,
		  expand_entities => 1,
		  recover => 1,
		 );
  %opts = (%defaults,%opts);
  my $key  = join(', ', map {"$_=>".($opts{$_} ? 1 : 0)} sort(keys(%defaults)));
  return $LIBXML_PARSERS{$key} if ($LIBXML_PARSERS{$key});

  my $parser = $LIBXML_PARSERS{$key} = XML::LibXML->new();
  $parser->keep_blanks($opts{keep_blanks}||0);     ##-- do we want blanks kept?
  $parser->expand_entities($opts{expand_ents}||0); ##-- do we want entities expanded?
  $parser->line_numbers($opts{line_numbers}||0);
  $parser->load_ext_dtd($opts{load_ext_dtd}||0);
  $parser->validation($opts{validation}||0);
  $parser->recover($opts{recover}||0);
  return $parser;
}

##==============================================================================
## Utils: XML::LibXSLT
##==============================================================================

## $XSLT
##  + package-global shared XML::LibXSLT object (or undef)
our $XSLT = undef;

## $xslt = PACKAGE::xsl_xslt()
##  + returns XML::LibXSLT object
sub xsl_xslt {
  $XSLT = XML::LibXSLT->new() if (!$XSLT);
  return $XSLT;
}

## $stylesheet = PACKAGE::xsl_stylesheet(file=>$xsl_file)
## $stylesheet = PACKAGE::xsl_stylesheet(fh=>$xsl_fh)
## $stylesheet = PACKAGE::xsl_stylesheet(doc=>$xsl_doc)
## $stylesheet = PACKAGE::xsl_stylesheet(string=>$xsl_string)
sub xsl_stylesheet {
  my ($what,$src) = @_;
  my $xmlparser = libxml_parser(line_numbers=>1);

  my ($doc);
  if ($what eq 'file') {
    $doc = $xmlparser->parse_file($src)
      or croak(__PACKAGE__, "::xsl_stylesheet(): failed to parse XSL source file '$src' as XML: $!");
  } elsif ($what eq 'fh') {
    $doc = $xmlparser->parse_fh($src)
      or croak(__PACKAGE__, "::xsl_stylesheet(): failed to parse XSL source filehandle as XML: $!");
  } elsif ($what eq 'doc') {
    $doc = $src;
  } elsif ($what eq 'string') {
    $doc = $xmlparser->parse_string($src)
      or croak(__PACKAGE__, "::xsl_stylesheet(): failed to parse XSL source string as XML: $!");
  } else {
    warn(__PACKAGE__, "::xsl_stylesheet(): treating unknown type key '$what' as 'string'");
    $doc = $xmlparser->parse_string(defined($src) ? $src : $what)
      or croak(__PACKAGE__, "::xsl_stylesheet(): failed to parse XSL source string as XML: $!");
  }
  croak(__PACKAGE__, "::xsl_stylesheet(): no XSL source document!") if (!$doc);

  my $xslt = xsl_xslt();
  my $stylesheet = $xslt->parse_stylesheet($doc)
    or croak(__PACKAGE__, "::xsl_stylesheet(): could not parse XSL stylesheet: $!");

  return $stylesheet;
}

##==============================================================================
## Utils: I/O: slurp
##==============================================================================

## \$txtbuf = PACKAGE::slurp_file($filename_or_fh)
## \$txtbuf = PACKAGE::slurp_file($filename_or_fh,\$txtbuf)
BEGIN { *slurp_fh = \&slurp_file; }
sub slurp_file {
  my ($file,$bufr) = @_;
  if (!defined($bufr)) {
    my $buf = '';
    $bufr = \$buf;
  }
  my $fh = $file;
  if (!ref($file)) {
    $fh = IO::File->new("<$file")
      or die(__PACKAGE__, "::slurp_file(): open failed for file '$file': $!");
    $fh->binmode();
  }
  local $/=undef;
  $$bufr = <$fh>;
  $fh->close if (!ref($file));
  return $bufr;
}

##==============================================================================
## Utils: Files
##==============================================================================

## $mtime_in_floating_seconds = file_mtime($filename_or_fh)
##  + de-references symlinks
sub file_mtime {
  my $file = shift;
  my @stat = (UNIVERSAL::can('Time::HiRes','stat') ? Time::HiRes::stat($file) : stat($file));
  return $stat[9];
}

## $bool = PACKAGE::file_is_newer($dstFile, \@depFiles, $requireMissingDeps)
##  + returns true if $dstFile is newer than all existing @depFiles
##  + if $requireMissingDeps is true, non-existent @depFiles will cause this function to return false
sub file_is_newer {
  my ($dst,$deps,$requireMissingDeps) = @_;
  my $dst_mtime = file_mtime($dst);
  return 0 if (!defined($dst_mtime));
  my ($dep_mtime);
  foreach (UNIVERSAL::isa($deps,'ARRAY') ? @$deps : $deps) {
    $dep_mtime = file_mtime($_);
    return 0 if ( defined($dep_mtime) ? $dep_mtime >= $dst_mtime : $requireMissingDeps );
  }
  return 1;
}

## $bool = file_try_open($filename)
##  + tries to open() $filename; returns true if successful
sub file_try_open {
  my $file = shift;
  my ($fh);
  eval { $fh = IO::File->new("<$file"); };
  $fh->close() if (defined($fh));
  return defined($fh);
}

## $abs_path_to_file = abs_path($file)
##  + de-references symlinks
##  + imported from Cwd
sub abs_path { Cwd::abs_path(@_); }

## $bool = str2file($string,$filename_or_fh,\%opts)
##  + dumps $string to $filename_or_fh
##  + %opts: see ref2file()
sub str2file { ref2file(\$_[0],@_[1..$#_]); }

## $bool = ref2file($stringRef,$filename_or_fh,\%opts)
##  + dumps $$stringRef to $filename_or_fh
##  + %opts:
##     binmode => $layer,  ##-- binmode layer (e.g. ':raw') for $filename_or_fh? (default=none)
sub ref2file {
  my ($ref,$file,$opts) = @_;
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  #__PACKAGE__->logconfess("ref2file(): open failed for '$file': $!") if (!$fh);
  return undef if (!$fh);
  if ($opts && $opts->{binmode}) {
    $fh->binmode($opts->{binmode}) || return undef;
  }
  $fh->print($$ref) || return undef;
  if (!ref($file)) { $fh->close() || return undef; }
  return 1;
}

##==============================================================================
## Utils: Time
##==============================================================================

## $floating_seconds_since_epoch = PACAKGE::timestamp()
sub timestamp { return Time::HiRes::time(); }
#BEGIN { *timestamp = \&Time::HiRes::time; }

##==============================================================================
## Utils: SI
##==============================================================================

## $si_str = sistr($val, $printfFormatChar, $printfFormatPrecision)
sub sistr {
  my ($x, $how, $prec) = @_;
  $how  = 'f' if (!defined($how));
  $prec = '.2' if (!defined($prec));
  my $fmt = "%${prec}${how}";
  return sprintf("$fmt T", $x/10**12) if ($x >= 10**12);
  return sprintf("$fmt G", $x/10**9)  if ($x >= 10**9);
  return sprintf("$fmt M", $x/10**6)  if ($x >= 10**6);
  return sprintf("$fmt K", $x/10**3)  if ($x >= 10**3);
  return sprintf("$fmt  ", $x)        if ($x >=  1);
  return sprintf("$fmt m", $x*10**3)  if ($x >= 10**-3);
  return sprintf("$fmt u", $x*10**6)  if ($x >= 10**-6);
  return sprintf("$fmt  ", $x); ##-- default
}


##==============================================================================
## Utils: Misc
##==============================================================================

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, and edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Utils - DTA tokenizer wrappers: generic utilities

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Utils qw(:files :slurp :progs :libxml :libxslt :time :si);
 
 ##========================================================================
 ## Utils: external programs
 
 $progpath_or_undef = path_prog($progname,%opts);
 $exitval = runcmd(@cmd);
 
 ##========================================================================
 ## Utils: XML::LibXML
 
 $parser = libxml_parser(%opts);
 
 ##========================================================================
 ## Utils: XML::LibXSLT
 
 $xslt = xsl_xslt();
 $stylesheet = xsl_stylesheet(file=>$xsl_file);
 
 ##========================================================================
 ## Utils: I/O: slurp
 
 \$txtbuf = slurp_file($filename_or_fh);
 
 ##========================================================================
 ## Utils: Files
 
 $mtime_in_floating_seconds = file_mtime($filename_or_fh);
 $bool = file_is_newer($dstFile, \@depFiles, $requireMissingDeps);
 $bool = file_try_open($filename);
 $abs_path_to_file = abs_path($file);
 $bool = str2file($string,$filename_or_fh,\%opts);
 $bool = ref2file($stringRef,$filename_or_fh,\%opts);
 
 ##========================================================================
 ## Utils: Time
 
 $stamp = timestamp();
 
 ##========================================================================
 ## Utils: SI
 
 $si_str = sistr($val, $printfFormatChar, $printfFormatPrecision);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::TokWrap::Utils provides diverse assorted miscellaneous utilities
which don't fit well anywhere else and which don't on their own justify
the creation of a new package.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Utils: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Utils inherits from
L<DTA::TokWrap::Logger|DTA::TokWrap::Logger>.

=item $TRACE_RUNCMD

Log-level for tracing runcmd() calls.  Default='trace'.
See L<DTA::TokWrap::Logger|DTA::TokWrap::Logger> for details.

Exported under the C<:progs> tag.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Utils: Utils: external programs
=pod

=head2 Utils: external programs

The following are exported under the C<:progs> tag:

=over 4

=item path_prog

 $progpath_or_undef = DTA::TokWrap::Utils::path_prog($progname,%opts);

Attempt to find an executable program $progname in $ENV{PATH}.

Known %opts:

 prepend => \@paths,  ##-- prepend @paths to Env::Path->PATH->List
 append  => \@paths,  ##-- append @paths to Env::Path->PATH->List
 warnsub => \&sub,    ##-- warn subroutine if program not found (undef for no warnings)

=item runcmd

 $exitval = DTA::TokWrap::Utils::runcmd(@cmd);

Just a wrapper for system() with optional logging
via L<DTA::TokWrap::Logger|DTA::TokWrap::Logger>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Utils: Utils: XML::LibXML
=pod

=head2 Utils: XML::LibXML

The following are exported by the C<:libxml> tag:

=over 4

=item Variable: %LIBXML_PARSERS

%LIBXML_PARSERS

XML::LibXML parsers, keyed by parser attribute strings (see libxml_parser())

=item libxml_parser

 $parser = libxml_parser(%opts);

Known %opts (see L<XML::LibXML(3pm)|XML::LibXML> for details):

 line_numbers    => $bool,  ##-- default: 1
 load_ext_dtd    => $bool,  ##-- default: 0
 validation      => $bool,  ##-- default: 0
 keep_blanks     => $bool,  ##-- default: 1
 expand_entities => $bool,  ##-- default: 1
 recover         => $bool,  ##-- default: 1

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Utils: Utils: XML::LibXSLT
=pod

=head2 Utils: XML::LibXSLT

The following are exported by the C<:libxslt> tag:

=over 4

=item Variable: $XSLT

Package-global shared XML::LibXSLT object (or undef)

=item xsl_xslt

 $xslt = DTA::TokWrap::Utils::xsl_xslt();

Returns XML::LibXSLT object ($XSLT).

=item xsl_stylesheet

 $stylesheet = DTA::TokWrap::Utils::xsl_stylesheet(file=>$xsl_file);
 $stylesheet = DTA::TokWrap::Utils::xsl_stylesheet(fh=>$xsl_fh)
 $stylesheet = DTA::TokWrap::Utils::xsl_stylesheet(doc=>$xsl_doc)
 $stylesheet = DTA::TokWrap::Utils::xsl_stylesheet(string=>$xsl_string)

Compile an XSL stylesheet from specified source.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Utils: Utils: I/O: slurp
=pod

=head2 Utils: I/O: slurp

The following are exported by the C<:slurp> tag:

=over 4

=item slurp_file

 \$txtbuf = DTA::TokWrap::Utils::slurp_file($filename_or_fh);
 \$txtbuf = DTA::TokWrap::Utils::slurp_file($filename_or_fh,\$txtbuf)

Slurp an entire file into a string.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Utils: Utils: Files
=pod

=head2 Utils: Files

The following are exported by the C<:files> tag:

=over 4

=item file_mtime

 $mtime_in_floating_seconds = file_mtime($filename_or_fh);

Get file modification time.  De-references symlinks.
Uses Time::HiRes::stat() if available, otherwise perl core function stat().

=item file_is_newer

 $bool = DTA::TokWrap::Utils::file_is_newer($dstFile, \@depFiles, $requireMissingDeps);

Returns true if $dstFile is newer than all existing @depFiles.
If $requireMissingDeps is true, non-existent @depFiles will cause this function to return false.

=item file_try_open

 $bool = file_try_open($filename);

Tries to open() $filename; returns true if successful, otherwise populates $! with
the relevant OS error message.

=item abs_path

 $abs_path_to_file = abs_path($file);

Get absolute path for a file or directory. De-references symlinks.

Imported from the C<Cwd> module.

=item str2file

 $bool = str2file($string,$filename_or_fh,\%opts);

Dumps a string $string to a file $filename_or_fh.
Opposite of L<slurp_file>().

%opts: see L<ref2file>().

=item ref2file

 $bool = ref2file($stringRef,$filename_or_fh,\%opts);

Dumps $$stringRef to $filename_or_fh.
Opposite of L<slurp_file>().

%opts:

 binmode => $layer,  ##-- binmode layer (e.g. ':raw') for $filename_or_fh? (default=none)

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Utils: Utils: timestamp
=pod

The following are exported by the C<:time> tag:

=head2 Utils: Time

=over 4

=item time

 $floating_seconds_since_epoch = PACAKGE::timestamp()

Just a wrapper for L<Time::HiRes|Time::HiRes>::time().

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Utils: Utils: SI
=pod

=head2 Utils: SI

The following are exported by the C<:si> tag:

=over 4

=item sistr

 $si_str = sistr($val, $printfFormatChar, $printfFormatPrecision);

Returns an SI string for numeric value $val.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl
=pod



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

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut

=cut


=cut
