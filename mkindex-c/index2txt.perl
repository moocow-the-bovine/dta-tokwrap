#!/usr/bin/perl -w

our @implicit_tokbreak_elts = qw(div p fw figure item list ref);  ##-- implicit token break on START and END
our %implicit_tokbreak_elts = map { ($_=>undef) } @implicit_tokbreak_elts;
our $TOKBREAK = "\n\$TB\$\n";

open(IX2,">tmp.ix")
  or die("$0: open failed for 'tmp.ix': $!");

our ($id,$xbo,$xbl,$txt, @tmp);
our $pos = 0;
our $oline = 1;
while (<>) {
  chomp;
  ($id,$xbo,$xbl,$txt) = split(/\t/,$_);
  if ($id eq '$START$' && $txt eq 'lb') {
    $_ = "\n";
    next;
  }
  elsif (($id eq '$START$' || $id eq '$END$') && exists($implicit_tokbreak_elts{$txt})) {
    $_ = $TOKBREAK;
    next;
  }
  elsif ($id =~ /^\$.*\$$/) {
    ##-- some other special event: skip it
    $_ = '';
    next;
  }
  $txt =~ s/\\n/\n/g;
  $txt =~ s/\\t/\t/g;
  $txt =~ s/\\\\/\\/g;
  $_ = $txt;
} continue {
  print $_;
  print IX2 "$.\t$pos\t$oline\n";
  $pos += length($_);
  $oline += scalar(@tmp=($_ =~ /\n/g));
}
print IX2 "$.\t$pos\n";
