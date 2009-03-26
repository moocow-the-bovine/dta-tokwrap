#!/usr/bin/perl -w

our $magic_str    = "dta-tokwrap-index";
our $fileversion  = 1;
our $PACKAS_MAGIC = 'Z[32]LC';
our $magic        = pack($PACKAS_MAGIC, $magic_str, $fileversion, ord("\n"));

our $head  = ''; ##-- header
our $body  = ''; ##-- packed character events
our %attrs = qw();

our $PACKAS_FILE = 'Z*';
our $PACKAS_ID = 'Z*';
our $PACKAS_BO = 'L';
our $PACKAS_BL = 'C';

##-- $PACKAS_CHAR: for pack($PACKAS_CHAR, $xml_id, $xml_byte_offset,$xml_byte_len, $txt_byte_offset,$txt_byte_len)
our $PACKAS_CHAR = $PACKAS_ID.$PACKAS_BO.$PACKAS_BL.$PACKAS_BO.$PACKAS_BL;

##-- $PACKAS_HEAD: for pack($PACKAS_HEAD, $filename, $n_xml_celts, $n_txt_bytes)
our $PACKAS_HEAD = $PACKAS_FILE.$PACKAS_BO.$PACKAS_BO;

our (@rest);
while (<>) {
  chomp;
  if ($_ =~ /^%% (?:BEGIN )?(FILE|NCHARS|NBYTES) (.*)/) {
    $attrs{lc($1)} = $2;
    next;
  }
  elsif ($_ =~ /^%%/) {
    next;
  }
  @fields = split(/\t/,$_); ##-- id, xmlbo,xmlbl, txtbo,txtbl, @debug
  $body .= pack($PACKAS_CHAR, @fields);
}

##-- output
$head = pack($PACKAS_HEAD, @attrs{qw(file nchars nbytes)});
print $magic, $head, $body;
