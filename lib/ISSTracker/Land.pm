package ISSTracker::Land;
use Mojo::Base -base;
use Mojo::File 'path';
use Mojo::JSON 'decode_json';
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

1;
