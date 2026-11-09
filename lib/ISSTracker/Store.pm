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

sub has_observation {
  my ($self, $timestamp) = @_;
  return defined $self->sqlite->db->query('SELECT 1 FROM observations WHERE observed_at = ?', $timestamp)->array;
}

sub history {
  my ($self, $limit, $before) = @_;
  my $sql = 'SELECT * FROM observations';
  my @bind;
  if (defined $before) {
    $sql .= ' WHERE observed_at < ?';
    push @bind, $before;
  }
  return $self->sqlite->db->query("$sql ORDER BY observed_at DESC LIMIT ?", @bind, $limit)->hashes->to_array;
}

sub track_since {
  my ($self, $since) = @_;
  return $self->sqlite->db->query(
    'SELECT observed_at, latitude, longitude FROM observations WHERE observed_at >= ? ORDER BY observed_at',
    $since
  )->hashes->to_array;
}

1;
