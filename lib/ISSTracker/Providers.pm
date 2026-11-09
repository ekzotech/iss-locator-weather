package ISSTracker::Providers;
use Mojo::Base -base;
use Mojo::UserAgent;
use Scalar::Util 'looks_like_number';
use POSIX 'isfinite';

has 'iss_url';

has ua => sub {
  return Mojo::UserAgent->new(connect_timeout => 5, inactivity_timeout => 8, request_timeout => 12);
};

sub iss_position_p {
  my $self = shift;
  return $self->ua->get_p($self->iss_url)->then(sub { return $self->parse_iss(shift->result->json) });
}

sub parse_iss {
  my ($self, $payload) = @_;
  die 'Invalid ISS position' unless ref($payload) eq 'HASH' && ref($payload->{iss_position}) eq 'HASH';
  my ($latitude, $longitude) = @{$payload->{iss_position}}{qw(latitude longitude)};
  die 'Invalid ISS coordinates' unless _finite_number($latitude) && _finite_number($longitude)
    && abs($latitude) <= 90 && abs($longitude) <= 180;
  my $timestamp = $payload->{timestamp};
  die 'Invalid ISS timestamp' unless _finite_number($timestamp)
    && $timestamp >= 0 && $timestamp <= 253402300799 && int($timestamp) == $timestamp;
  return {latitude => 0 + $latitude, longitude => 0 + $longitude, observed_at => 0 + $timestamp};
}

sub _finite_number {
  my $value = shift;
  return !ref($value) && looks_like_number($value) && isfinite($value);
}

1;
