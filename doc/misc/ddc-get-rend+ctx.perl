#!/usr/bin/perl -w

my %rend=qw();
my %ctx =qw();
my ($l,@l,%lctx);
my ($argv);
while (<>) {
  if (!$argv || $ARGV ne $argv) {
    print STDERR "$0: processing $ARGV...\n";
    $argv=$ARGV;
  }
  chomp;
  next if ($_ !~ m|<l>(.*)</l>\s*$|);
  $l=$1;
  @l = split(/\t/,$l);

  ##-- parse: rend
  ++$rend{$_} foreach (grep {defined($_) && $_ ne ''} split(/\|/,$l[5]));

  ##-- parse: ctx (unique only)
  %lctx = map {($_=>undef)} grep {defined($_) && $_ ne ''} split(/\|/,$l[6]);
  ++$ctx{$_} foreach (keys %lctx);
}

##-- dump: rend
foreach (sort {$rend{$b}<=>$rend{$a}} keys %rend) {
  print "REND\t", $rend{$_}, "\t", $_, "\n";
}
print "\n";

##-- dump: ctx
foreach (sort {$ctx{$b}<=>$ctx{$a}} keys %ctx) {
  print "CTX\t", $ctx{$_}, "\t", $_, "\n";
}
