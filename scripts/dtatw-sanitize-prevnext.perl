#!/usr/bin/perl -w

use XML::LibXML;

push(@ARGV,'-') if (!@ARGV);
my $xmlfile = shift;
my $xmldoc = XML::LibXML->load_xml(location=>$xmlfile) or die("$0: load failed for '$xmlfile': $!");

##-- look for nodes with @prev, @next
my ($nod,$nodid,$refid,$refnod);
my $id=0;
foreach $nod (@{$xmldoc->findnodes('//*[@prev or @next]')}) {
  $nodid = $nod->getAttribute('id') || $nod->getAttribute('xml:id') || $nod->getAttribute('xml_id');
  if (!defined($nodid)) {
    ##-- add @id
    $nodid = sprintf("pnauto.%0.4x", ++$id);
    $nod->setAttribute('xml:id'=>$nodid);
  }
  if (defined($refid = $nod->getAttribute('prev'))) {
    ##-- sanitize @prev
    $refid  =~ s/^\#//;
    $refnod = $xmldoc->findnodes("id('$refid')")->[0];
    if (!$refnod) {
      $nod->removeAttribute('prev');
    }
    elsif (!$refnod->getAttribute('next')) {
      $refnod->setAttribute('next'=>$nodid);
    }
  }
  if (defined($refid = $nod->getAttribute('next'))) {
    ##-- sanitize @next
    $refid  =~ s/^\#//;
    $refnod = $xmldoc->findnodes("id('$refid')")->[0];
    if (!$refnod) {
      $nod->removeAttribute('next');
    }
    elsif (!$refnod->getAttribute('prev')) {
      $refnod->setAttribute('prev'=>$nodid);
    }
  }
}

$xmldoc->toFH(\*STDOUT,0);
