#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode encode_utf8 decode_utf8);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;

use strict;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);
our $verbose = 1;     ##-- print progress messages by default
our ($help);

##-- debugging
our $DEBUG = 0;

##-- vars: I/O
our $basefile = "-";   ##-- default: stdin
our $sofile   = undef; ##-- required
our $outfile  = "-";   ##-- default: stdout

##-- selection
our $keep_ws = 0;
our $keep_text  = 0;
our $ignore_attrs = '';
our $ignore_elts  = '';
our $old_content_elt = '';
our (@ignore_attrs,%ignore_elts);

##-- constants: verbosity levels
our $vl_progress = 1;

our ($outfh); ##-- forward decl

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,
	   'verbose|v=i' => \$verbose,
	   'quiet|q' => sub { $verbose=!$_[1]; },

	   ##-- I/O
	   'keep-whitespace|whitespace|space|keep-blanks|blanks|ws!' => \$keep_ws,
	   'keep-text|text|t!' => \$keep_text,
	   'ignore-attrs|ia=s' => \$ignore_attrs,
	   'ignore-elements|ignore-elts|ie=s' => \$ignore_elts,
	   'wrap-content|wc|w=s' => \$old_content_elt,
	   'output|out|o=s' => \$outfile,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-message=>"Not enough arguments given!",-exitval=>0,-verbose=>0}) if (@ARGV < 2);


##-- command-line: arguments
($basefile, $sofile) = @ARGV;
%ignore_elts  = map {($_=>undef)} grep {defined($_)} split(/[\s\,\|]+/,$ignore_elts);
@ignore_attrs =                   grep {defined($_)} split(/[\s\,\|]+/,$ignore_attrs);

##======================================================================
## Subs: escaping

## $escaped = xmlesc($str)
our ($esc);
sub xmlesc {
  $esc = $_[0];
  $esc =~ s|\&|\&amp;|sg;
  $esc =~ s|\"|\&quot;|sg;
  $esc =~ s|\'|\&apos;|sg;
  $esc =~ s|\<|\&lt;|sg;
  $esc =~ s|\>|\&gt;|sg;
  $esc =~ s|([\x{0}-\x{1f}])|'&#'.ord($1).';'|sge;
  return utf8::is_utf8($esc) ? encode_utf8($esc) : $esc;
}

##======================================================================
## Subs: standoff-xml (e.g. .cab.xml)

##--------------------------------------------------------------
## XML::Parser handlers (for standoff .w.xml file)

our ($_xp, $_elt, %_attrs);

our @xids = qw();        ##-- stack of nearest-ancestor (xml:)?id values; 1 entry for each currently open element
our $xid = undef;        ##-- (xml:)?id of most recently opened element with an id
our %so_content = qw();  ##-- %so_content = ($id => $so_content, ...)
our %so_attrs   = qw();  ##-- %so_attrs   = ($id => \%attrs, ...)

## undef = cb_init($expat)
sub so_cb_init {
  #($_xp) = @_;
  %so_content = qw();
  %so_attrs   = qw();
  @xids       = qw();
  $xid        = undef;
}

## undef = cb_start($expat, $elt,%attrs)
our ($eid);
sub so_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  %_attrs = @_[2..$#_];
  if (defined($eid = $_attrs{'id'} || $_attrs{'xml:id'})) {
    delete(@_attrs{qw(id xml:id),@ignore_attrs});
    $so_attrs{$eid} = {%_attrs} if (%_attrs);
    $xid = $eid;
  }
  push(@xids,$xid);
  $_[0]->default_current if (!defined($eid) && !exists($ignore_elts{$_[1]}));
}

## undef = cb_end($expat,$elt)
sub so_cb_end {
  $eid=pop(@xids);
  $xid=$xids[$#xids];
  $_[0]->default_current if (!exists($ignore_elts{$_[1]}) && (!defined($eid) || !defined($xid) || $eid eq $xid));
}

### undef = cb_char($expat,$string)
sub so_cb_char {
  $_[0]->default_current() if ($keep_text);
}

## undef = cb_default($expat, $str)
our ($content);
sub so_cb_default {
  $so_content{$xid} .= $_[0]->original_string if (defined($xid))
}

## undef = cb_final($expat)
sub so_cb_final {
  if (!$keep_ws) {
    foreach $xid (keys %so_content) {
      $content = $so_content{$xid};
      $content =~ s/\s+/ /sg;
      if ($content =~ /^\s*$/) {
	delete($so_content{$xid});
      } else {
	$so_content{$xid} = $content;
      }
    }
  }
}


##======================================================================
## Subs: source-file stuff (.chr.xml)

our $n_merged_attrs = 0;
our $n_merged_content = 0;
our @wrapstack = qw();

## undef = cb_init($expat)
sub base_cb_init {
  #($_xp) = @_;
  $n_merged_attrs = 0;
  $n_merged_content = 0;
  @wrapstack = qw();
}

## undef = cb_final($expat)
#sub base_cb_final {
#  base_flush_segment();
#  return \@w_segs0;
#}

## undef = cb_start($expat, $elt,%attrs)
our ($is_empty, $so_attrs, $id);
sub base_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  %_attrs = @_[2..$#_];
  push(@wrapstack,undef);
  return $_[0]->default_current if (!defined($id=$_attrs{'id'} || $_attrs{'xml:id'}));

  ##-- merge in standoff attributes if available (clobber)
  if (defined($so_attrs=$so_attrs{$id})) {
    %_attrs = (%_attrs, %$so_attrs);
    $n_merged_attrs++;
  }
  $outfh->print(join(' ',"<$_[1]", map {"$_=\"".xmlesc($_attrs{$_}).'"'} keys %_attrs));

  ##-- merge in standoff content if available (prepend)
  $is_empty = ($_[0]->original_string =~ m|/>$|);
  $wrapstack[$#wrapstack] = $old_content_elt if (!$is_empty);
  if (defined($content=$so_content{$id})) {
    $outfh->print(">", $content, ($is_empty ? "</$_[1]>" : ($old_content_elt ? "<$old_content_elt>" : qw())));
    $n_merged_content++;
  }
  elsif ($is_empty) {
    $outfh->print("/>");
  }
  else {
    $outfh->print(">", ($old_content_elt ? "<$old_content_elt>" : qw()));
  }
}

## undef = cb_end($expat, $elt)
our ($wrap);
sub base_cb_end {
  #($_xp,$_elt) = @_;
  $wrap = pop(@wrapstack);
  $outfh->print("</$wrap>") if ($wrap);
  $_[0]->default_current;
}

### undef = cb_char($expat,$string)
#sub base_cb_char {
#  $_[0]->default_current;
#}

## undef = cb_default($expat, $str)
sub base_cb_default {
  $outfh->print($_[0]->original_string);
}


##======================================================================
## MAIN

##-- initialize XML::Parser (for .w.xml file)
our $xp_so = XML::Parser->new(
			      ErrorContext => 1,
			      ProtocolEncoding => 'UTF-8',
			      #ParseParamEnt => '???',
			      Handlers => {
					   Init  => \&so_cb_init,
					   Char  => \&so_cb_char,
					   Start => \&so_cb_start,
					   End   => \&so_cb_end,
					   Default => \&so_cb_default,
					   Final => \&so_cb_final,
					  },
			     )
  or die("$prog: couldn't create XML::Parser for standoff file");

##-- initialize output file(s)
$outfh = IO::File->new(">$outfile")
  or die("$prog: open failed for output file '$outfile': $!");

##-- load standoff data
print STDERR "$prog: parsing standoff file '$sofile'...\n"
  if ($verbose>=$vl_progress);
$xp_so->parsefile($sofile);
print STDERR "$prog: parsed ", scalar(keys(%so_attrs)), " attribute-lists and ", scalar(keys(%so_content)), " content-strings from '$sofile'.\n"
  if ($verbose>=$vl_progress);

##-- merge standoff data into base file
print STDERR "$prog: merging standoff data into base file '$basefile'...\n"
  if ($verbose>=$vl_progress);
our $xp_base = XML::Parser->new(
				ErrorContext => 1,
				ProtocolEncoding => 'UTF-8',
				#ParseParamEnt => '???',
				Handlers => {
					     Init   => \&base_cb_init,
					     #XmlDecl => \&base_cb_xmldecl,
					     #Char  => \&base_cb_char,
					     Start  => \&base_cb_start,
					     End    => \&base_cb_end,
					     Default => \&base_cb_default,
					     #Final   => \&base_cb_final,
					    },
			       )
  or die("$prog: couldn't create XML::Parser for base file '$basefile'");

$xp_base->parsefile($basefile);

##-- report
sub pctstr {
  my ($n,$total,$label) = @_;
  return sprintf("%d %s (%.2f%%)", $n, $label, ($total==0 ? 'nan' : (100*$n/$total)));
}
print STDERR
  ("$prog: merged ",
   pctstr($n_merged_attrs, scalar(keys %so_attrs), 'attribute-lists'),
   " and ", 
   pctstr($n_merged_content, scalar(keys %so_content), 'content-strings'),
   " from '$sofile' into '$basefile'.\n",
  )
  if ($verbose>=$vl_progress);


__END__

=pod

=head1 NAME

dtatw-splice.perl - splice generic standoff data into base XML files

=head1 SYNOPSIS

 dtatw-splice.perl [OPTIONS] BASE_XML_FILE STANDOFF_XML_FILE

 General Options:
  -help                  # this help message
  -verbose LEVEL         # set verbosity level (0<=LEVEL<=1)
  -quiet                 # be silent

 I/O Options:
  -blanks , -noblanks    # don't/do keep 'ignorable' whitespace in standoff file (default=ignored)
  -text   , -notext      # do/don't splice in standoff text data (default=do)
  -ignore-attrs LIST     # comma-separated list of standoff attributes to ignore (default=none)
  -ignore-elts LIST      # comma-separated-list of standoff content elements to ignore (default=none)
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

Splice generic standoff data into base XML files.

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
