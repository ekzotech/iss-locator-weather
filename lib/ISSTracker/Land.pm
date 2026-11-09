package ISSTracker::Land;
use Mojo::Base -base;
use Mojo::File 'path';
use Mojo::JSON 'decode_json';
use List::Util qw(min max);
use POSIX 'isfinite';
use Scalar::Util 'looks_like_number';

has polygons => sub { [] };

sub from_file {
  my ($class, $filename) = @_;
  my $document = eval { decode_json(path($filename)->slurp) };
  die "Cannot read land GeoJSON at $filename: $@" if $@;
  die "Invalid land GeoJSON collection at $filename"
    unless ref($document) eq 'HASH' && ($document->{type} // '') eq 'FeatureCollection'
    && ref($document->{features}) eq 'ARRAY' && @{$document->{features}};

  my @polygons;
  for my $feature (@{$document->{features}}) {
    die "Invalid land feature at $filename"
      unless ref($feature) eq 'HASH' && ($feature->{type} // '') eq 'Feature'
      && ref($feature->{geometry}) eq 'HASH';
    my ($type, $coordinates) = @{$feature->{geometry}}{qw(type coordinates)};
    die "Invalid land geometry at $filename"
      unless defined($type) && ($type eq 'Polygon' || $type eq 'MultiPolygon')
      && ref($coordinates) eq 'ARRAY' && @$coordinates;
    my @parts = $type eq 'Polygon' ? ($coordinates) : @$coordinates;
    for my $polygon (@parts) {
      die "Invalid land polygon at $filename"
        unless ref($polygon) eq 'ARRAY' && @$polygon && !grep { !_valid_ring($_) } @$polygon;
      push @polygons, $polygon;
    }
  }
  return $class->new(polygons => \@polygons);
}

sub _valid_ring {
  my $ring = shift;
  return unless ref($ring) eq 'ARRAY' && @$ring >= 4;
  for my $position (@$ring) {
    return unless ref($position) eq 'ARRAY' && @$position >= 2;
    my ($longitude, $latitude) = @$position;
    return if grep { ref($_) || !looks_like_number($_) || !isfinite($_) } $longitude, $latitude;
    return if abs($longitude) > 180 || abs($latitude) > 90;
  }
  return $ring->[0][0] == $ring->[-1][0] && $ring->[0][1] == $ring->[-1][1];
}

sub contains {
  my ($self, $latitude, $longitude) = @_;
  for my $polygon (@{$self->polygons}) {
    my ($exterior, @holes) = @$polygon;
    next unless _ring_contains($exterior, $longitude, $latitude);
    next if grep { _ring_contains($_, $longitude, $latitude) == 1 } @holes;
    return 1;
  }
  return 0;
}

sub _ring_contains {
  my ($ring, $x, $y) = @_;
  my $inside = 0;
  for my $i (1 .. $#$ring) {
    my ($x1, $y1) = @{$ring->[$i - 1]};
    my ($x2, $y2) = @{$ring->[$i]};
    if ($x >= min($x1, $x2) && $x <= max($x1, $x2) && $y >= min($y1, $y2) && $y <= max($y1, $y2)) {
      my $cross = ($x - $x1) * ($y2 - $y1) - ($y - $y1) * ($x2 - $x1);
      return 2 if abs($cross) <= 1e-10;
    }
    next if ($y1 > $y) == ($y2 > $y);
    my $crossing = $x1 + ($y - $y1) * ($x2 - $x1) / ($y2 - $y1);
    $inside = !$inside if $x < $crossing;
  }
  return $inside ? 1 : 0;
}

1;
