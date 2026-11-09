package ISSTracker::Collector;
use Mojo::Base -base;

has [qw(providers store land)];

sub collect_p {
  my $self = shift;
  return $self->providers->iss_position_p->then(sub {
    my $point = shift;
    my @coordinates = @$point{qw(latitude longitude)};
    return $self->store->record({%$point, weather_status => 'water'}) unless $self->land->contains(@coordinates);
    return $self->providers->weather_p(@coordinates)->then(sub {
      my $weather = shift;
      return {%$point, %$weather, weather_status => 'available'};
    }, sub {
      return {%$point, weather_status => 'unavailable'};
    })->then(sub { return $self->store->record(shift) });
  });
}

1;
