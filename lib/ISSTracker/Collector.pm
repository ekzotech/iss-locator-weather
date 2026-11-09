package ISSTracker::Collector;
use Mojo::Base -base;

has [qw(providers store)];

sub collect_p {
  my $self = shift;
  return $self->providers->iss_position_p->then(sub {
    my $point = shift;
    return $self->store->record({%$point, weather_status => 'unavailable'});
  });
}

1;
