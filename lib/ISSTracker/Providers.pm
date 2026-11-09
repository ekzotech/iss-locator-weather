package ISSTracker::Providers;
use Mojo::Base -base;
use Mojo::UserAgent;

has 'iss_url';

has ua => sub {
  return Mojo::UserAgent->new(connect_timeout => 5, inactivity_timeout => 8, request_timeout => 12);
};

sub iss_position_p {
  my $self = shift;
  return $self->ua->get_p($self->iss_url)->then(sub { return shift->result->json });
}

1;
