package ISSTracker;
use Mojo::Base 'Mojolicious';
use Mojo::File 'path';
use Mojo::Home;

my $root = path(__FILE__)->to_abs->dirname->dirname;

sub startup {
  my $self = shift;
  $self->home(Mojo::Home->new($root));
  $self->renderer->paths([$root->child('templates')]);
  $self->static->paths([$root->child('public')]);
  my $db_path = $ENV{ISS_TRACKER_DB};
  $self->config->{db_path} = defined($db_path) && length($db_path)
    ? path($db_path)->to_abs->to_string
    : $root->child('var', 'observations.sqlite')->to_string;
  $self->config->{iss_url} = $ENV{ISS_TRACKER_ISS_URL} || 'http://api.open-notify.org/iss-now.json';
  $self->config->{weather_url} = $ENV{ISS_TRACKER_WEATHER_URL} || 'https://api.open-meteo.com/v1/forecast';
}

1;
