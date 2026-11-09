package ISSTracker::Map;
use strict;
use warnings;
use Exporter 'import';
use List::Util 'min';

our @EXPORT_OK = qw(distance_km project MAP_WIDTH MAP_HEIGHT);
use constant { MAP_WIDTH => 720, MAP_HEIGHT => 360 };

my $radians_per_degree = atan2(0, -1) / 180;
my $earth_radius_km = 6371.0088;

sub distance_km {
  my ($latitude1, $longitude1, $latitude2, $longitude2) = @_;
  my $lat1 = $latitude1 * $radians_per_degree;
  my $lat2 = $latitude2 * $radians_per_degree;
  my $half_lon_delta = ($longitude2 - $longitude1) * $radians_per_degree / 2;
  my $haversine = sin(($lat2 - $lat1) / 2)**2 + cos($lat1) * cos($lat2) * sin($half_lon_delta)**2;
  $haversine = min(1, $haversine);
  return 2 * $earth_radius_km * atan2(sqrt($haversine), sqrt(1 - $haversine));
}

sub project {
  my ($latitude, $longitude) = @_;
  return [($longitude + 180) * MAP_WIDTH / 360, (90 - $latitude) * MAP_HEIGHT / 180];
}

1;
