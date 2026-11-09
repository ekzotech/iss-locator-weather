package ISSTracker::Store;
use Mojo::Base -base;

has 'sqlite';

sub record {
  my ($self, $observation) = @_;
  die 'Observation timestamp is required' unless defined $observation->{observed_at};
  return $self->sqlite->db->query(<<'SQL', @$observation{qw(observed_at latitude longitude weather_status temperature_c cloud_cover weather_code weather_at)})->rows;
INSERT INTO observations (
  observed_at, latitude, longitude, weather_status, temperature_c, cloud_cover, weather_code, weather_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(observed_at) DO NOTHING
SQL
}

sub latest {
  return shift->sqlite->db->query('SELECT * FROM observations ORDER BY observed_at DESC LIMIT 1')->hash;
}

1;
