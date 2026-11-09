package ISSTrackerTest;
use strict;
use warnings;
use Exporter 'import';
use Mojo::File 'tempdir';
use Test::Mojo;
use Mojolicious;

our @EXPORT_OK = qw(new_tracker new_mock_tracker await_p);

sub new_tracker {
  my $dir = tempdir;
  local $ENV{ISS_TRACKER_DB} = $dir->child('observations.sqlite')->to_string;
  return (Test::Mojo->new('ISSTracker'), $dir);
}

sub new_mock_tracker {
  my ($tracker, $dir) = new_tracker();
  my $mock = Mojolicious->new;
  my $state = {
    iss => {message => 'success', timestamp => 1704067260, iss_position => {latitude => '48.85', longitude => '2.35'}},
    weather => {current => {temperature_2m => 0, cloud_cover => 25, weather_code => 1, time => 1704067200}},
    weather_requests => 0,
  };
  $mock->routes->get('/iss' => sub { shift->render(json => $state->{iss}) });
  $mock->routes->get('/weather' => sub {
    my $c = shift;
    ++$state->{weather_requests};
    $c->render(status => $state->{weather_status} // 200, json => $state->{weather});
  });
  $tracker->app->providers->ua(Test::Mojo->new($mock)->ua)->iss_url('/iss')->weather_url('/weather');
  return ($tracker, $dir, $state);
}

sub await_p {
  my $promise = shift;
  my ($result, $error);
  $promise->then(sub { $result = shift }, sub { $error = shift })->wait;
  return ($result, $error);
}

1;
