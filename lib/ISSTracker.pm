package ISSTracker;
use Mojo::Base 'Mojolicious';
use Mojo::File 'path';
use Mojo::Home;
use Mojo::SQLite;
use ISSTracker::Store;
use ISSTracker::Providers;
use ISSTracker::Land;
use ISSTracker::Collector;
use ISSTracker::View 'view_observation';
use ISSTracker::Map qw(land_svg_path MAP_WIDTH MAP_HEIGHT);

use constant TRACK_WINDOW => 2 * 60 * 60;

my $root = path(__FILE__)->to_abs->dirname->dirname;

has sqlite => sub {
  my $self = shift;
  my $db_path = path($self->config->{db_path});
  $db_path->dirname->make_path;
  my $sqlite = Mojo::SQLite->new->from_filename($db_path->to_string);
  $sqlite->on(connection => sub { $_[1]->sqlite_busy_timeout(5000) });
  $sqlite->migrations->name('iss_tracker')->from_file($root->child('migrations', 'observations.sql'))->migrate;
  return $sqlite;
};
has store => sub { ISSTracker::Store->new(sqlite => shift->sqlite) };
has providers => sub {
  my $config = shift->config;
  return ISSTracker::Providers->new(iss_url => $config->{iss_url}, weather_url => $config->{weather_url});
};
has land => sub { ISSTracker::Land->from_file($root->child('data', 'ne_110m_land.geojson')) };
has land_path => sub { land_svg_path(shift->land->polygons) };
has collector => sub {
  my $self = shift;
  return ISSTracker::Collector->new(
    providers => $self->providers, store => $self->store, land => $self->land, log => $self->log
  );
};

sub startup {
  my $self = shift;
  push @{$self->commands->namespaces}, 'ISSTracker::Command';
  $self->home(Mojo::Home->new($root));
  $self->renderer->paths([$root->child('templates')]);
  $self->static->paths([$root->child('public')]);
  my $db_path = $ENV{ISS_TRACKER_DB};
  $self->config->{db_path} = defined($db_path) && length($db_path)
    ? path($db_path)->to_abs->to_string
    : $root->child('var', 'observations.sqlite')->to_string;
  $self->config->{iss_url} = $ENV{ISS_TRACKER_ISS_URL} || 'http://api.open-notify.org/iss-now.json';
  $self->config->{weather_url} = $ENV{ISS_TRACKER_WEATHER_URL} || 'https://api.open-meteo.com/v1/forecast';
  $self->sqlite;
  $self->helper(track_points => sub { shift->app->store->track_recent(TRACK_WINDOW) });

  $self->routes->get('/health' => sub {
    shift->render(json => {status => 'ok'});
  });
  $self->routes->get('/' => sub {
    my $c = shift;
    my @observations = map { view_observation($_) } @{$c->app->store->history(20)};
    $c->render(
      template => 'dashboard',
      latest => $observations[0],
      observations => \@observations,
      land_path => $c->app->land_path,
      map_width => MAP_WIDTH,
      map_height => MAP_HEIGHT,
    );
  })->name('dashboard');
  $self->routes->get('/api/latest' => sub {
    my $c = shift;
    $c->render(json => {observation => view_observation(scalar $c->app->store->latest)});
  });
  $self->routes->get('/api/history' => sub {
    my $c = shift;
    my $limit = $c->param('limit') // 20;
    my $before = $c->param('before');
    return $c->render(status => 400, json => {error => 'limit must be an integer from 1 to 100'})
      unless $limit =~ /\A[1-9][0-9]{0,2}\z/ && $limit <= 100;
    return $c->render(status => 400, json => {error => 'before must be a Unix timestamp'})
      if defined($before) && ($before !~ /\A[0-9]{1,12}\z/ || $before > 253402300799);
    my $observations = $c->app->store->history($limit + 1, $before);
    my $next;
    if (@$observations > $limit) {
      pop @$observations;
      $next = $observations->[-1]{observed_at};
    }
    $c->render(json => {observations => [map { view_observation($_) } @$observations], next_before => $next});
  });
  $self->routes->get('/api/track' => sub {
    my $c = shift;
    $c->render(json => {points => $c->track_points});
  });
}

1;
