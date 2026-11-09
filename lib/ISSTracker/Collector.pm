package ISSTracker::Collector;
use Mojo::Base -base;

has [qw(providers store land)];

sub collect_p {
  my $self = shift;
  return $self->providers->iss_position_p->then(sub {
    my $point = shift;
    my $over_land = $self->land->contains(@$point{qw(latitude longitude)});
    return $self->store->record({%$point, weather_status => $over_land ? 'unavailable' : 'water'});
  });
}

1;
