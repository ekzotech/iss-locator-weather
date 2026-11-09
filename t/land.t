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

done_testing;
