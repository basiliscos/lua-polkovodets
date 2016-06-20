use strict;
use warnings;

use Path::Tiny;

my $data = path($ARGV[0])->slurp;
my %map = (
  m51	=> 'A0',
  m50	=> 'W0',
  m52	=> 'X0',
  m54	=> 'Q0',
  m49	=> 'U0',
  m53	=> 'O0',
  '~2' => '~0',
  '~3' => '~1',
  '~4' => '~2',
  m47 => 'S0',
  t3 => 't4',
  t2 => 't3',
  t1 => 't2',
  t0 => 't1',
  m48 => 't0',
  m61 => 'L0',
  m62 => 'L1',
  m63 => 'L2',
  m64 => 'L3',
  m65 => 'L4',
  m66 => 'L5',
  m67 => 'L6',
  m68 => 'L7',
  m69 => 'L8',
  m70 => 'L9',
  m71 => 'L10',
  m72 => 'L11',
  m73 => 'L12',
  m74	=> 'L13',
  m75 => 'L14',
  m76 => 'L15',
  m77 => 'L16',
  m78 => 'L17',
);

while (my ($from, $to) = each %map) {
  $data =~ s/\Q$from\E/$to/g;
}

path($ARGV[0])->spew($data);
