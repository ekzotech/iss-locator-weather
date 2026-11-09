package ISSTracker::Store;
use Mojo::Base -base;

has 'sqlite';

sub record {
  my ($self, $observation) = @_;
  return $self->sqlite->db->query(<<'SQL', @$observation{qw(observed_at latitude longitude weather_status temperature_c cloud_cover weather_code weather_at)})->rows;
INSERT INTO observations (
  observed_at, latitude, longitude, weather_status, temperature_c, cloud_cover, weather_code, weather_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
SQL
}

1;
