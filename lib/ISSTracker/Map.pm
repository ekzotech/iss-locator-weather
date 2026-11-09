package ISSTracker::Map;
use strict;
use warnings;
use Exporter 'import';
use List::Util 'min';

our @EXPORT_OK = qw(distance_km project land_svg_path track_segments map_overlay MAP_WIDTH MAP_HEIGHT);
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

sub land_svg_path {
  my $polygons = shift;
  my @rings;
  for my $polygon (@$polygons) {
    for my $ring (@$polygon) {
      my @positions = map { sprintf('%.2f,%.2f', @{project($_->[1], $_->[0])}) } @$ring;
      push @rings, 'M' . join(' ', @positions) . 'Z';
    }
  }
  return join '', @rings;
}

sub track_segments {
  my $points = shift;
  return [] unless @$points;
  my @projected = map { project(@$_{qw(latitude longitude)}) } @$points;
  my @segments = ([$projected[0]]);
  for my $i (1 .. $#projected) {
    my ($previous, $next) = @projected[$i - 1, $i];
    my ($x1, $y1) = @$previous;
    my ($x2, $y2) = @$next;
    if (abs($x2 - $x1) > MAP_WIDTH / 2) {
      my $edge = $x1 > $x2 ? MAP_WIDTH : 0;
      my $opposite = MAP_WIDTH - $edge;
      my $span = $x2 + $edge - $opposite - $x1;
      my $fraction = $span ? ($edge - $x1) / $span : 0.5;
      my $y = $y1 + ($y2 - $y1) * $fraction;
      push @{$segments[-1]}, [$edge, $y];
      push @segments, [[$opposite, $y]];
    }
    push @{$segments[-1]}, $next;
  }
  return \@segments;
}

sub map_overlay {
  my ($latest, $points) = @_;
  my $segments = track_segments($points);
  return {
    marker => $latest ? [map { sprintf('%.2f', $_) } @{project(@$latest{qw(latitude longitude)})}] : undef,
    lines => [map { join ' ', map { sprintf('%.2f,%.2f', @$_) } @$_ } grep { @$_ >= 2 } @$segments],
  };
}

1;
