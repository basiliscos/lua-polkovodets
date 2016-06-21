use strict;
use warnings;

use Path::Tiny;

my $data = path($ARGV[0])->slurp;
my %map = (
  m51	 => 'A0',
  m50	 => 'W0',
  m52	 => 'X0',
  m54	 => 'Q0',
  m49	 => 'U0',
  m53	 => 'O0',
  '~2' => '~0',
  '~3' => '~1',
  '~4' => '~2',
  m47  => 'S0',
  t0   => 't1',
  t1   => 't2',
  t2   => 't3',
  t3   => 't4',
  m48  => 't0',
  m61  => 'L0',
  m62  => 'L1',
  m63  => 'L2',
  m64  => 'L3',
  m65  => 'L4',
  m66  => 'L5',
  m67  => 'L6',
  m68  => 'L7',
  m69  => 'L8',
  m70  => 'L9',
  m71  => 'L10',
  m72  => 'L11',
  m73  => 'L12',
  m74	 => 'L13',
  m75  => 'L14',
  m76  => 'L15',
  m77  => 'L16',
  m78  => 'L17',
  r2   => 'r0',
  r5   => 'r1',
  r6   => 'r2',
  r7   => 'r3',
  r8   => 'r4',
  r9   => 'r5',
  r10  => 'r6',
  r11  => 'r7',
  r13  => 'r8',
  r14  => 'r9',
  r15  => 'r10',
  r16  => 'r11',
  r18  => 'r12',
  r0   => 'b0',
  r1   => 'b1',
  r3   => 'b2',
  r4   => 'b3',
  r12  => 'b4',
  r17  => 'b5',
  r27  => 'b6',
  r28  => 'b7',
  r29  => 'b8',
  r30  => 'b9',
);

my $next_pair = sub {
  my $result;
  while (my ($from, $to) = each %map) {
    if (not $map{$to}) {
      delete $map{$from};
      return [$from, $to];
    }
  }

};

while (my $pair = $next_pair->()) {
  my ($from, $to) = @$pair;
  $data =~ s/\Q$from\E/$to/g;
}
path($ARGV[0])->spew($data);
