#!/usr/bin/perl -w

##======================================================================
## Globals

##-- blocks by key
our $blks = {};

##======================================================================
## Subs

## $nbytes = slurp_textfile($filename,\$txtref)
sub slurp_textfile {
  my ($filename,$txtref) = @_;
  use bytes;
  open(SLURP,"<$filename") or die("$0: open failed for slurp from '$filename': $!");
  binmode(SLURP);
  local $/ = undef;
  $$txtref = <SLURP>;
  close(SLURP);
  return length($$txtref);
}

## \%blocks = read_blockfile($blkfile)
sub read_blockfile {
  my ($filename) = shift;
  open(BLOCKS,"<$filename")
    or die("$0: open failed for block-file '$filename': $!");
  my $blks = {};
  my ($blk, $id, $xoff,$xlen, $toff,$tlen, $key);
  while (<BLOCKS>) {
    chomp;
    next if (/^%%/ || /^\s*$/);
    ($id, $xoff,$xlen, $toff,$tlen, $key) = split(/\t/,$_);
    if (!defined($blk=$blks->{$key})) {
      $blk = $blks->{$key} = { key=>$key, xranges=>[], tranges=>[] };
    }
    push(@{$blk->{xranges}}, [$xoff,$xlen]);
    push(@{$blk->{tranges}}, [$toff,$tlen]);
  }
  close(BLOCKS);
  return $blks;
}


##======================================================================
## MAIN

##-- command-line
our ($bxfile,$txfile) = @ARGV;

##-- slurp text file
our $txbuf = '';
our $slurped = slurp_textfile($txfile,\$txbuf);
print STDERR "$0: read $slurped bytes from text file '$txfile'\n";

##-- read block-file into index
$blks = read_blockfile($bxfile);
print STDERR "$0: read ", scalar(keys(%$blks)), " blocks from block file '$bxfile'\n";

our ($id,$xoff,$xlen,$toff,$tlen,$key);
