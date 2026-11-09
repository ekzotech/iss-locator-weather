package ISSTracker::Providers;
use Mojo::Base -base;
use Mojo::UserAgent;
use Scalar::Util 'looks_like_number';

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
  die 'Invalid ISS coordinates'
    unless !ref($latitude) && !ref($longitude) && looks_like_number($latitude) && looks_like_number($longitude);
  return {latitude => 0 + $latitude, longitude => 0 + $longitude, observed_at => $payload->{timestamp}};
}

1;
