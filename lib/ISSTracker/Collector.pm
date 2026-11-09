package ISSTracker::Collector;
use Mojo::Base -base;

has [qw(providers store land log)];
has _outages => sub { {} };

sub collect_p {
  my $self = shift;
  return $self->providers->iss_position_p->catch(sub {
    $self->_report('Open Notify', 0);
    die shift;
  })->then(sub {
    my $point = shift;
    $self->_report('Open Notify', 1);
    return 0 if $self->store->has_observation($point->{observed_at});
    my @coordinates = @$point{qw(latitude longitude)};
    return $self->store->record({%$point, weather_status => 'water'}) unless $self->land->contains(@coordinates);
    return $self->providers->weather_p(@coordinates)->then(sub {
      my $weather = shift;
      $self->_report('Open-Meteo', 1);
      return {%$point, %$weather, weather_status => 'available'};
    }, sub {
      $self->_report('Open-Meteo', 0);
      return {%$point, weather_status => 'unavailable'};
    })->then(sub { return $self->store->record(shift) });
  });
}

sub _report {
  my ($self, $provider, $available) = @_;
  if ($available) {
    $self->log->info("$provider recovered") if delete $self->_outages->{$provider};
  } elsif (!$self->_outages->{$provider}) {
    $self->_outages->{$provider} = 1;
    $self->log->warn("$provider unavailable");
  }
}

1;
