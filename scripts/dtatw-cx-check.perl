#!/usr/bin/perl -w
use bytes;
if (!@ARGV || grep {/^\-+h/} @ARGV) {
  print STDERR "Usage: $0 CXFILE [TXFILE]\n";
  exit 1;
}

my $cxfile = shift;
my $txfile = shift;
if (!$txfile) {
  ($txfile=$cxfile) =~ s/\.cx$/.tx/;
}

##-- get buffers
my ($txbuf);
{
  local $/=undef;
  open(TX,"<$txfile") or die("$0: open failed for $txfile: $!");
  $txbuf = <TX>;
  close TX;
}

open(CX,"<$cxfile") or die("$0: open failed for $cxfile: $!");
my ($elt,$xoff,$xlen,$toff,$tlen,$txt,$attrs);
while (<CX>) {
  next if (/^\%\%/ || /^\s*$/);
  chomp;
  ($elt,$xoff,$xlen,$toff,$tlen,$txt,$attrs) = split(/\t/,$_,7);
  next if ($elt !~ /^(?:c|\-|lb)$/);
  $txt =~ s/\\n/\n/g;
  $txt =~ s/\\t/\t/g;
  $txt =~ s/\\\\/\\/g;
  if (substr($txbuf,$toff,$tlen) ne $txt) {
    warn("text mismatch for cx record '$_'; text='$txt' != '", substr($txbuf,$toff,$tlen), "'=txbuf");
  }
}
print "done\n";
