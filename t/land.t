use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ISSTracker::Land;
use Mojo::File 'tempfile';
use Test::More;

my $land = ISSTracker::Land->from_file("$FindBin::Bin/../data/ne_110m_land.geojson");
is scalar(@{$land->polygons}), 127, 'bundled land geometry loads';
my $invalid = tempfile;
$invalid->spew('{');
eval { ISSTracker::Land->from_file($invalid) };
like $@, qr/Cannot read land GeoJSON/, 'invalid JSON fails with context';
$invalid->spew('{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,1]]]}}]}');
eval { ISSTracker::Land->from_file($invalid) };
like $@, qr/Invalid land polygon/, 'an open polygon ring is rejected';

my $rectangle = [[0, 0], [10, 0], [10, 5], [0, 5], [0, 0]];
my $region = ISSTracker::Land->new(polygons => [[$rectangle]]);
ok $region->contains(2, 8), 'point inside the exterior ring is on land';
ok !$region->contains(8, 2), 'point outside the exterior ring is excluded';
my $lake = [[2, 1], [4, 1], [4, 3], [2, 3], [2, 1]];
my $with_lake = ISSTracker::Land->new(polygons => [[$rectangle, $lake]]);
ok !$with_lake->contains(2, 3), 'an interior hole is water';
ok $with_lake->contains(2, 8), 'the area outside the hole is still land';
ok $with_lake->contains(2, 4), 'the shore of an interior hole is land';
ok $region->contains(5, 10), 'a polygon vertex is land';
ok $region->contains(5, 8), 'a point on an exterior edge is land';
my $duplicate_vertex = ISSTracker::Land->new(polygons => [[[ [0, 0], @$rectangle ]]]);
ok !$duplicate_vertex->contains(8, 2), 'a zero-length edge does not classify unrelated points';

my @mismatch;
for my $y (-1 .. 6) {
  for my $x (-1 .. 11) {
    my $expected = $x >= 0 && $x <= 10 && $y >= 0 && $y <= 5 && !($x > 2 && $x < 4 && $y > 1 && $y < 3);
    push @mismatch, [$x, $y] if $with_lake->contains($y, $x) != ($expected ? 1 : 0);
  }
}
is_deeply \@mismatch, [], 'bounding box preserves exact classification throughout the sample grid';

done_testing;
