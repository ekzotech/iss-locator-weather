package ISSTracker::View;
use strict;
use warnings;
use utf8;
use Exporter 'import';
use POSIX 'strftime';
use ISSTracker::Weather 'weather_label';

our @EXPORT_OK = qw(view_observation is_stale);
use constant STALE_AFTER => 180;

my %status_label = (
  available => 'Над сушей',
  water => 'Над водой',
  unavailable => 'Погода недоступна',
);

sub view_observation {
  my $observation = shift;
  return undef unless $observation;
  my ($timestamp, $weather_at, $latitude, $longitude) = @$observation{qw(observed_at weather_at latitude longitude)};
  my ($temperature, $cloud_cover) = @$observation{qw(temperature_c cloud_cover)};
  return {
    %$observation,
    display => {
      observed_iso => _iso_time($timestamp),
      observed_utc => strftime('%d.%m.%Y, %H:%M:%S UTC', gmtime($timestamp)),
      weather_iso => _iso_time($weather_at),
      weather_utc => defined($weather_at) ? strftime('%H:%M UTC', gmtime($weather_at)) : undef,
      coordinates => sprintf('%.2f°, %.2f°', $latitude, $longitude),
      status => $status_label{$observation->{weather_status}},
      conditions => weather_label($observation->{weather_code}),
      temperature => defined($temperature) ? sprintf('%g °C', $temperature) : undef,
      cloud_cover => defined($cloud_cover) ? sprintf('%g %%', $cloud_cover) : undef,
    },
  };
}

sub is_stale {
  my ($observed_at, $now) = @_;
  return defined($observed_at) && $now - $observed_at >= STALE_AFTER;
}

sub _iso_time {
  my $timestamp = shift;
  return defined($timestamp) ? strftime('%Y-%m-%dT%H:%M:%SZ', gmtime($timestamp)) : undef;
}

1;
