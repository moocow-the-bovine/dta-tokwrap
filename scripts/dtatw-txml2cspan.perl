#!/usr/bin/perl -w

use XML::LibXML;
use Getopt::Long (':config'=>'no_ignore_case');
use File::Basename qw(basename);
use Encode qw(encode decode);
use Pod::Usage;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);

our $outfile  = '-';
our $encoding = 'UTF-8';
our $format   = 1;
our $expand_ents = 0;
our $keep_blanks = 0;

our $cxfile  = undef; ##-- default: none
our $span_attr = 'cs';

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- other
	   'cxfile|cxf|cx|c=s' => \$cxfile,

	   ##-- formatting
	   'entities|ent|e!' => sub { $expand_ents=!$_[1]; },
	   'blanks|b!'       => sub { $keep_blanks=$_[1]; },
	   'format|f:i'   =>sub { $format=$_[1] ? $_[1] : 1; },
	   'noformat|nof' =>sub { $format=0; },

	   ##-- output
	   'output|o=s'=>\$outfile,
	  );

pod2usage({-exitval=>0, -verbose=>0})
  if ($help);
#pod2usage({-exitval=>0, -verbose=>0, -msg=>'-textfile must be specified when reading from stdin!'})
#  if (!@ARGV || $ARGV[0] eq '-');

##------------------------------------------------------------------------------
## Subs
##------------------------------------------------------------------------------

## undef = load_cxfile($cxfile)
our (%c2prev); ##-- ($cid[$i] => $cid[$i-1])
sub load_cxfile {
  my $cxfile = shift;
  %c2prev = qw();
  open(CX,"<$cxfile") or die("$0: load_cxfile(): open failed for '$cxfile': $!");
  my ($pcid,$cid);
  while (defined($cid=<CX>)) {
    chomp($cid);
    next if ($cid =~ /^\s*$/ || $cid =~ /^\%\%/);
    #next if ($cid =~ /^\$/);
    $cid =~ s/\t.*$//;
    $c2prev{$cid} = $pcid;
    $pcid = $cid;
  }
  return \%c2prev;
}

## $doc = txml2cspan($doc)
##  + uses global $txtbufr
sub txml2cspan {
  my $doc = shift;

  ##-- adjacency predicate
  my $char_adjacent_sub = defined($cxfile) ? \&char_adjacent_cx : \&char_adjacent_guess;

  my ($wnod,$wc,@wcids,@wspans,$spans);
  my $wnods = $doc->findnodes('//w');
  foreach $wnod (@$wnods) {
    $wc    = $wnod->getAttribute('c');
    @wcids  = split(/\s+/,$wc);
    @wspans = ([0,0]); ##-- ([$from_i1,$to_i1], [$from_i2,$to_i2], ...)

    for ($ci=1; $ci <= $#wcids; $ci++) {
      if ($char_adjacent_sub->($wcids[$wspans[$#wspans][1]], $wcids[$ci])) {
	$wspans[$#wspans][1] = $ci;
      } else {
	push(@wspans, [$ci,$ci]);
      }
    }

    $spans = join(' ', map {$_->[0]==$_->[1] ? $wcids[$_->[0]] : "$wcids[$_->[0]]-$wcids[$_->[1]]"} @wspans);
    $wnod->removeAttribute('c') if ($span_attr ne 'c');
    $wnod->setAttribute($span_attr,$spans);
  }
  return $doc;
}

## $bool = char_adjacent_cx($cid1, $cid2)
##  + returns true iff "${cid1}${cid2}" is a substring of all cids
##  + uses global \%c2prev
our ($cp);
sub char_adjacent_cx {
  $cp = $c2prev{$_[1]};
  return defined($cp) && $cp eq $_[0];
}

## $bool = char_adjacent_guess($cid1, $cid2)
##  + returns true iff "${cid1}${cid2}" is a substring of all cids
##  + uses heuristics
our ($p1,$n1, $p2,$n2);
sub char_adjacent_guess {
  ($p1,$n1) = ($_[0] =~ m/^(.*?)(\d+)$/ ? ($1,$2) : ($_[0],-1));
  ($p2,$n2) = ($_[1] =~ m/^(.*?)(\d+)$/ ? ($1,$2) : ($_[1],-1));
  return ($p1 eq $p2 && $n2 == $n1+1);
}


##------------------------------------------------------------------------------
## MAIN
##------------------------------------------------------------------------------

##-- ye olde guttes
push(@ARGV,'-') if (!@ARGV);

our $parser = XML::LibXML->new();
$parser->keep_blanks($keep_blanks);     ##-- do we want blanks kept?
$parser->expand_entities($expand_ents); ##-- do we want entities expanded?
$parser->line_numbers(1);
$parser->load_ext_dtd(0);
$parser->validation(0);
$parser->recover(1);

##-- parse input .cx file
load_cxfile($cxfile) if (defined($cxfile));

##-- parse input XML
our $infile = shift;
our $doc   = $parser->parse_file($infile)
  or die("$prog: could not parse input .t.xml file '$infile': $!");

##-- munge & dump
$doc = txml2cspan($doc);
$doc->toFile($outfile,$format);

__END__
=pod

=head1 NAME

dtatw-txml2cspan.perl - DTA::TokWrap: compute character spans for .t.xml files

=head1 SYNOPSIS

 dtaec-txml2cspan.perl [OPTIONS] [TXMLFILE]

 General Options:
  -help                  # this help message

 Processing Options:
  -cxfile CXFILE         # use character adjacency data from CXFILE (default=use heuristic)

 I/O Options:
  -ent    , -noent       # don't/do expand entities (default=don't (-ent))
  -blanks , -noblanks    # do/don't keep "ignorable" input blanks (default=don't (-noblanks))
  -ws     , -nows        # do/don't keep token-internal whitespace (default=don't (-nows))
  -format , -noformat    # do/don't pretty-print output? (default=do (-format))
  -output OUTFILE        # specify output file (default='-' (STDOUT))

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

Not yet written.

=cut

##------------------------------------------------------------------------------
## See Also
##------------------------------------------------------------------------------
=pod

=head1 SEE ALSO

...

=cut


##------------------------------------------------------------------------------
## Footer
##------------------------------------------------------------------------------
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=cut
