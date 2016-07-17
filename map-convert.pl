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
  m74  => 'L13',
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
  R11  => 'b10',
  m27  => '~0',
  m25  => 'c19',
  m26  => 'c20',
  m28  => 'b11',
  m29  => 'b12',
  m30  => 'b13',
  m31  => 'b14',
  m32  => 't5',
  m33  => 't6',
  m34  => 'G0',
  m35  => 'G1',
  m36  => 'G2',
  m37  => 'G3',
  m38  => 'G4',
  m39  => 'G5',
  m40  => 'G6',
  m41  => 'G7',
  m42  => 'G8',
  m43  => 'G9',
  R13  => 'R11',
  R14  => 'G10',
  R15  => 'G11',
  F16  => 'Y0',
);

my $next_pair = sub {
  my $result;
  # while (my ($from, $to) = each %map) {
  for my $from (keys %map) {
    my $to = $map{$from};
    if (not exists $map{$to}) {
      $result = [$from, $to];
      delete $map{$from};
      last;
    }
  }
  return $result;
};

while (my $pair = $next_pair->()) {
  my ($from, $to) = @$pair;
  print("$from -> $to\n");
  $data =~ s/\Q$from\E(?!\d)/$to/g;
}
path($ARGV[0])->spew($data);
