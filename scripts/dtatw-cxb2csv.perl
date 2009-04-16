#!/usr/bin/perl -w

{
  local $/=undef;
  our $cxbuf = <>;
}

##-- test magic
($magic,$fileversion) = unpack('Z[32]I',$cxbuf);
die("$0: bad magic '$magic'") if ($magic ne "dtatw-mkindex:cx\n");
die("$0: can't handle .cx file version '$fileversion' > 1") if ($fileversion > 1);

##-- get number of records
our $packlen_long = length(pack('L!',0));
our $n_chr = unpack('L!',substr($cxbuf,length($cxbuf)-$packlen_long));

##-- unpack
$packlen_hdr = 32+length(pack('I!',0));
substr($cxbuf,0,$packlen_hdr) = '';
while ($cxbuf =~ m/\G([^\0]*\0.{$packlen_long}..{$packlen_long}.[^\0]*\0)/ogs) {
  ($id,$xoff,$xlen,$toff,$tlen,$text) = unpack('(Z*)L!CL!C(Z*)',$1);
  $text =~ s/\\/\\\\/g;
  $text =~ s/\t/\\t/g;
  $text =~ s/\n/\\n/g;
  print join("\t", $id,$xoff,$xlen,$toff,$tlen,$text), "\n";
}
##--
#@cxvals = unpack("((Z*)L!CL!C(Z*))[$n_chr]",substr($cxbuf,$packlen_hdr));
#foreach $i (0..(scalar(@cxvals)/6-1)) {
#  #($id,$xoff,$xlen,$toff,$tlen,$text) = @cxvals[($i*6)..($i*6+5)];
#  #$text =~ s/\\/\\\\/g;
#  #$text =~ s/\t/\\t/g;
#  #$text =~ s/\n/\\n/g;
#  #print join("\t", $id,$xoff,$xlen,$toff,$tlen,$text), "\n";
#  ##--
#  $text = $cxvals[$i*6+5];
#  $text =~ s/\\/\\\\/g;
#  $text =~ s/\t/\\t/g;
#  $text =~ s/\n/\\n/g;
#  print join("\t", @cxvals[($i*6)..($i*6+4)], $text), "\n";
#}
#--
#our $offset = $packlen_hdr;
#our $packlen_num = length(pack('L!CL!C'));
#our $cxbuflen = length($cxbuf);
#while ($offset < $cxbuflen) {
#  use bytes;
#  ($id,$xoff,$xlen,$toff,$tlen,$text) = unpack("\@${offset}(Z*)L!CL!C(Z*)", $cxbuf);
#  $offset += length(pack('(Z*)L!CL!C(Z*)',($id,$xoff,$xlen,$toff,$tlen,$text)));
#  $text =~ s/\\/\\\\/g;
#  $text =~ s/\t/\\t/g;
#  $text =~ s/\n/\\n/g;
#  print join("\t", $id,$xoff,$xlen,$toff,$tlen,$text), "\n";
#}
##--
#our $offset = $packlen_hdr;
#our $pack_template = '(Z*)L!CL!C(Z*)';
#while ($offset < length($cxbuf)) {
#  @record = ($id,$xoff,$xlen,$toff,$tlen,$text) = unpack($pack_template,substr($cxbuf,$offset));
#  $packlen = length(pack($pack_template, @record));
#  $offset += $packlen;
#  $text =~ s/\\/\\\\/g;
#  $text =~ s/\t/\\t/g;
#  $text =~ s/\n/\\n/g;
#  print join("\t", $id,$xoff,$xlen,$toff,$tlen,$text), "\n";
#}
##--
#@cx = unpack('((Z*)L!CL!C(Z*))*',substr($cxbuf,$packlen_hdr));
#while (@cx) {
#  ($id,$xoff,$xlen,$toff,$tlen,$text) = splice(@cx,0,6);
#  $text =~ s/\\/\\\\/g;
#  $text =~ s/\t/\\t/g;
#  $text =~ s/\n/\\n/g;
#  print join("\t", $id,$xoff,$xlen,$toff,$tlen,$text), "\n";
#}
