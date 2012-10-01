#!/usr/bin/perl -w

use Benchmark qw(cmpthese timethese);
use Encode qw(encode_utf8 decode_utf8);
use utf8;


my @su = (qw(Tanzſchuhe Bandſtellen ausführlich-deutlich Reichstagskommiſſion kühner Baſil. Miltzbeſchwerung Beſudelung ſoul),
	    qw(Blumenpflücken ſtärckeſte Kriegsgoͤtter fließendſte Amboſse Sommerfruͤchten Ungemeſſenem));
my @se = map {encode_utf8($_)} @su;

sub enc_u8 {
  utf8::encode($_[0]) if (utf8::is_utf8($_[0]));
  return $_[0];
}
sub enc_eu8 {
  $_[0] = encode_utf8($_[0]) if (utf8::is_utf8($_[0]));
  return $_[0];
}
sub enc_pack {
  $_[0] = pack('C0U*',unpack('C0C*',$_[0])) if (utf8::is_utf8($_[0]));
  return $_[0];
}

sub dec_u8 {
  utf8::decode($_[0]) if (!utf8::is_utf8($_[0]));
  return $_[0];
}
sub dec_eu8 {
  $_[0] = decode_utf8($_[0]) if (!utf8::is_utf8($_[0]));
  return $_[0];
}
sub dec_pack {
  $_[0] = pack('U0U*',unpack('C0U*',$_[0])) if (!utf8::is_utf8($_[0]));
  return $_[0];
}

my (@l);
my $n = -1;
cmpthese($n,
	 {
	  'enc_u8' => sub {@l=(@su,@se); enc_u8($_) foreach (@l);},
	  'enc_eu8' => sub {@l=(@su,@se); enc_eu8($_) foreach (@l);},
	  'enc_pack' => sub {@l=(@su,@se); enc_pack($_) foreach (@l);},
	 });

cmpthese($n,
	 {
	  'dec_u8' => sub {@l=(@su,@se); dec_u8($_) foreach (@l);},
	  'dec_eu8' => sub {@l=(@su,@se); dec_eu8($_) foreach (@l);},
	  'dec_pack' => sub {@l=(@su,@se); dec_eu8($_) foreach (@l);},
	 });
