package ISSTracker::Providers;
use Mojo::Base -base;
use Mojo::UserAgent;
use Mojo::URL;
use Scalar::Util 'looks_like_number';
use POSIX 'isfinite';

has 'iss_url';
has 'weather_url';

has ua => sub {
  return Mojo::UserAgent->new(connect_timeout => 5, inactivity_timeout => 8, request_timeout => 12);
};

sub iss_position_p {
  my $self = shift;
  return $self->_get_json_p($self->iss_url)->then(sub { return $self->parse_iss(shift) });
}

sub weather_p {
  my ($self, $latitude, $longitude) = @_;
  my $url = Mojo::URL->new($self->weather_url);
  $url->query->merge(
    latitude => $latitude, longitude => $longitude, current => 'temperature_2m,cloud_cover,weather_code',
    temperature_unit => 'celsius', timeformat => 'unixtime', timezone => 'UTC', cell_selection => 'nearest'
  );
  return $self->_get_json_p($url)->then(sub { return $self->parse_weather(shift) });
}

sub parse_weather {
  my ($self, $payload) = @_;
  die 'Invalid Open-Meteo current conditions' unless ref($payload) eq 'HASH' && ref($payload->{current}) eq 'HASH';
  my $temperature = $payload->{current}{temperature_2m};
  die 'Invalid Open-Meteo temperature' unless _finite_number($temperature);
  return {temperature_c => 0 + $temperature};
}

sub parse_iss {
  my ($self, $payload) = @_;
  die 'Open Notify did not report success' unless ref($payload) eq 'HASH' && ($payload->{message} // '') eq 'success';
  die 'Invalid ISS position' unless ref($payload->{iss_position}) eq 'HASH';
  my ($latitude, $longitude) = @{$payload->{iss_position}}{qw(latitude longitude)};
  die 'Invalid ISS coordinates' unless _finite_number($latitude) && _finite_number($longitude)
    && abs($latitude) <= 90 && abs($longitude) <= 180;
  my $timestamp = $payload->{timestamp};
  die 'Invalid ISS timestamp' unless _finite_number($timestamp)
    && $timestamp >= 0 && $timestamp <= 253402300799 && int($timestamp) == $timestamp;
  return {latitude => 0 + $latitude, longitude => 0 + $longitude, observed_at => 0 + $timestamp};
}

sub _get_json_p {
  my ($self, $url) = @_;
  return $self->ua->get_p($url)->then(sub {
    my $response = shift->result;
    die 'Provider returned HTTP ' . $response->code unless $response->is_success;
    my $json = $response->json;
    die 'Provider returned invalid JSON' unless ref($json) eq 'HASH';
    return $json;
  });
}

sub _finite_number {
  my $value = shift;
  return !ref($value) && looks_like_number($value) && isfinite($value);
}

1;
