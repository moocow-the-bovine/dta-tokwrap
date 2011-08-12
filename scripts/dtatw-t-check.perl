#!/usr/bin/perl -w

use bytes;

if (!@ARGV) {
  print STDERR "Usage: $0 TT_FILE [TXT_FILE]\n";
  exit 1;
}
$ttfile = shift;
$txtfile = shift;
if (!$txtfile) {
  ($txtfile=$ttfile)=~s/\.t[t0-9]*$//;
  $txtfile .= '.txt';
}

##-- buffer txtfile
{
  local $/=undef;
  open(TXT,"<$txtfile") or die("$0: open failed for '$txtfile': $!");
  binmode(TXT);
  $txtbuf = <TXT>;
  close(TXT);
}

my $warned=0;
my $max_warnings=10;
sub tokwarn {
  warn(@_);
  ++$warned;
}

##-- process .t file
open(TT,"<$ttfile") or die("$0: open failed for '$ttfile': $!");
my ($text,$pos,$rest, $off,$len, $buftext);
while (<TT>) {
  chomp;
  next if (/^\s*$/ || /^\%\%/); ##-- skip comments and blank lines
  ($text,$pos,$rest)=split(/\t/,$_,3);
  $toklabel = "token '$text\t$pos".($rest ? "\t$rest" : '')."' at $ttfile line $.";
  if (!defined($pos)) {
    tokwarn("$0: no position defined for $toklabel\n");
    next;
  }

  ##-- parse offset, length
  ($off,$len) = split(' ',$pos,2);
  if ($off+$len > length($txtbuf)) {
    tokwarn("$0: token offset+length=", ($off+$len), " > buffer length=", length($txtbuf), " for $toklabel\n");
    next;
  }

  ##-- check content
  $buftext = substr($txtbuf, $off,$len);
  $tokre   = join('', map {"\Q$_\E(?:(?:[ \n\r\t\-]|¬)*)"} split(//,$text));
  if ($buftext !~ $tokre) {
    tokwarn("$0: buffer text='$buftext' doesn't match token text for $toklabel\n");
  }

  ##-- check max warnings?
  if ($warned >= $max_warnings) {
    warn("$0: waximum number of warnings ($max_warnings) emitted -- bailing out");
    last;
  }
}
print "$0: $ttfile -> $txtfile : ", ($warned ? "NOT ok ($warned warnings)" : "ok"), "\n";
exit $warned;
