#!/usr/bin/perl -w

use lib qw(.);
use DTA::TokWrap;
use DTA::TokWrap::Utils ':libxml';
use File::Basename qw(basename dirname);
use strict;


##--------------------------------------------------------------
## buffer xml doc
my $xmlfile   = @ARGV ? shift : '-';
my $prog      = basename($0).": $xmlfile";
my ($xmlbuf);
{
  local $/=undef;
  open(XML,"<$xmlfile") or die("$prog: ERROR: open failed for XML file '$xmlfile': $!");
  $xmlbuf = <XML>;
  $xmlbuf =~ s|(<[^>]*\s)xmlns=|${1}XMLNS=|g;  ##-- remove default namespaces
  close XML;
}
my $xmlparser = libxml_parser(keep_blanks=>1,expand_entities=>1);
my $xmldoc    = $xmlparser->parse_string($xmlbuf)
  or die("$prog: ERROR: could not parse XML file '$xmlfile': $!");
my $root = $xmldoc->documentElement;

##--------------------------------------------------------------
## MAIN

##-- xpath context (not really needed, since we use xpath hack)
my $xc = XML::LibXML::XPathContext ->new($root);
$xc->registerNs(($_->declaredPrefix||'DEFAULT'),$_->declaredURI) foreach ($root->namespaces);
$xc->registerNs('tei',($root->getNamespaceURI||'')) if (!$root->lookupNamespaceURI('tei'));

my $idfmt = 'seg2pn_%d_%d';
my ($id_i,$id_j) = (0,0);
my $n_updated = 0;
my (@chain, $nod,$cur,$nxt, $pb1);

my $n_segs = scalar(@{$root->findnodes('//seg')});

CHAIN:
foreach $nod ($n_segs==0 ? qw() : @{$xc->findnodes('//seg[@part="I"]/note')}) {
  #++$n_suspects;
  @chain = qw();
  $id_j = 0;
  push(@chain, $cur={
		     nod=>$nod,
		     pb1=>$nod->findnodes('following::pb[1]')->[0],
		     n=>$nod->getAttribute('n'),
		     id=>($nod->getAttribute('xml:id') || $nod->getAttribute('id') || sprintf($idfmt,++$id_i,++$id_j)),
		    });
  ##-- sanity checks
  if (!$cur->{pb1}) {
    warn("$prog: no following::pb for //seg/note at line ", $nod->line_number, ": skipping chain");
    next CHAIN;
  }
  elsif (!$cur->{n}) {
    warn("$prog: no \@n attribute for //seg/note at line ", $nod->line_number, ": skipping chain");
    next CHAIN;
  }

 NODE:
  while (defined($nod=$cur->{nod}->findnodes('following::seg[string(@part)!="I"][1]/'.$cur->{nod}->nodeName)->[0])) {
    #++$n_suspects;
    push(@chain, $nxt={
		       nod=>$nod,
		       pb0=>$nod->findnodes('preceding::pb[1]')->[0],
		       pb1=>$nod->findnodes('following::pb[1]')->[0],
		       n=>($nod->getAttribute('n') || ''),
		       id=>($nod->getAttribute('xml:id') || $nod->getAttribute('id') || sprintf($idfmt,$id_i,++$id_j)),
		      });

    ##-- sanity check(s)
    if (!$nxt->{pb0} || !$nxt->{pb0}->isSameNode($cur->{pb1})) {
      warn("$prog: not exactly one intervening //pb for //seg/note at line ", $nod->line_number, ": skipping chain");
      next CHAIN;
    }
    elsif (!$cur->{n}) {
      warn("$prog: no \@n attribute for //seg/note at line ", $nod->line_number, ": skipping chain");
      next CHAIN;
    }
    elsif ($cur->{n} ne $nxt->{n}) {
      warn("$prog: \@n attribute mismatch for //seg/note at line ", $nod->line_number, ": skipping chain");
      next CHAIN;
    }

    ##-- final $seg1 node: remove it too
    last NODE if (($nod->parentNode->getAttribute('part')||'F') eq 'F');

    ##-- update and continue
    $cur = $nxt;
  }

  ##-- if we get here, we have an intact chain in @chain
  $cur = undef;
  foreach $nxt (@chain) {
    ##-- convert to @prev|@next
    $nxt->{nod}->setAttribute('xml:id' => $nxt->{id});
    $nxt->{nod}->setAttribute('prev'   => $cur->{id}) if ($cur);
    $cur->{nod}->setAttribute('next'   => $nxt->{id}) if ($cur);

    ##-- remove parent //seg nodes
    $nxt->{nod}->parentNode->replaceNode($nxt->{nod});
    $cur = $nxt;
  }
  $n_updated += scalar(@chain);
}
print STDERR sprintf("$prog: INFO: removed %d of %d <seg> node(s) (%.2f %%)\n",
		     $n_updated, $n_segs, ($n_segs==0 ? 'nan' : (100*$n_updated/$n_segs)));


##--------------------------------------------------------------
## dump
$xmlbuf = $xmldoc->toString(0);
$xmlbuf =~ s|(<[^>]*\s)XMLNS=|${1}xmlns=|g;  ##-- restore default namespaces

my $outfile = @ARGV ? shift : '-';
open(OUT,">$outfile") or die("$prog: ERROR: open failed for '$outfile': $!");
print OUT $xmlbuf;
close OUT or die("$prog: ERROR: failed to close output file '$outfile': $!");
