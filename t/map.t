use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ISSTracker::Map qw(distance_km project track_segments);
use Test::More;

is distance_km(45, 60, 45, 60), 0, 'identical points have zero distance';
cmp_ok abs(distance_km(0, 0, 0, 90) - 10007.56), '<', 0.02, 'quarter of the equator';
cmp_ok abs(distance_km(0, 179, 0, -179) - 222.39), '<', 0.02, 'short arc crosses the antimeridian';
cmp_ok abs(distance_km(0, 0, 0, 180) - 20015.11), '<', 0.02, 'antipodal points';
is_deeply project(90, -180), [0, 0], 'northwest corner projects to the SVG origin';
is_deeply project(-90, 180), [720, 360], 'southeast corner projects to the bottom right';
is_deeply project(0, 0), [360, 180], 'the equator and Greenwich cross at the center';
my $east = {latitude => 0, longitude => 179};
my $west = {latitude => 2, longitude => -179};
is_deeply track_segments([$east, $west]), [[[718, 180], [720, 178]], [[0, 178], [2, 176]]],
  'eastward crossing joins the same latitude on opposite map edges';
is_deeply track_segments([$west, $east]), [[[2, 176], [0, 178]], [[720, 178], [718, 180]]],
  'westward crossing joins the same latitude on opposite map edges';
is_deeply track_segments([{latitude => 0, longitude => 180}, {latitude => 2, longitude => -180}]),
  [[[720, 180], [720, 178]], [[0, 178], [0, 176]]], 'points on the seam do not divide by zero';
is_deeply track_segments([]), [], 'no points give no segments';
is_deeply track_segments([$east, {latitude => 1, longitude => 177}]), [[[718, 180], [714, 178]]],
  'nearby points stay in the same segment';

done_testing;
