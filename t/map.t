use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ISSTracker::Map qw(distance_km project);
use Test::More;

is distance_km(45, 60, 45, 60), 0, 'identical points have zero distance';
cmp_ok abs(distance_km(0, 0, 0, 90) - 10007.56), '<', 0.02, 'quarter of the equator';
cmp_ok abs(distance_km(0, 179, 0, -179) - 222.39), '<', 0.02, 'short arc crosses the antimeridian';
cmp_ok abs(distance_km(0, 0, 0, 180) - 20015.11), '<', 0.02, 'antipodal points';
is_deeply project(90, -180), [0, 0], 'northwest corner projects to the SVG origin';
is_deeply project(-90, 180), [720, 360], 'southeast corner projects to the bottom right';
is_deeply project(0, 0), [360, 180], 'the equator and Greenwich cross at the center';

done_testing;
