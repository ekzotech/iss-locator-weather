package ISSTracker;
use Mojo::Base 'Mojolicious';
use utf8;
use Mojo::File 'path';
use Mojo::Home;
use Mojo::SQLite;
use ISSTracker::Store;
use ISSTracker::Providers;
use ISSTracker::Land;
use ISSTracker::Collector;
use ISSTracker::View 'view_observation';
use ISSTracker::Map qw(land_svg_path map_overlay MAP_WIDTH MAP_HEIGHT);

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
  $self->helper(track_points => sub {
    my ($c, $until) = @_;
    return $c->app->store->track_recent(TRACK_WINDOW, $until);
  });
  $self->helper(history_page => sub {
    my ($c, $limit, $before) = @_;
    my $rows = $c->app->store->history($limit + 1, $before);
    my $next;
    if (@$rows > $limit) {
      pop @$rows;
      $next = $rows->[-1]{observed_at};
    }
    return {observations => [map { view_observation($_) } @$rows], next_before => $next};
  });
  $self->helper(dashboard_state => sub {
    my $c = shift;
    my $page = $c->history_page(20);
    my $latest = $page->{observations}[0];
    return {
      %$page,
      latest => $latest,
      overlay => map_overlay($latest, $latest ? $c->track_points($latest->{observed_at}) : []),
      map_description => $latest ? 'Последняя точка: ' . $latest->{display}{coordinates} : 'Последняя точка пока неизвестна.',
    };
  });

  $self->routes->get('/health' => sub {
    shift->render(json => {status => 'ok'});
  });
  $self->routes->get('/' => sub {
    my $c = shift;
    $c->render(
      template => 'dashboard',
      %{$c->dashboard_state},
      land_path => $c->app->land_path,
      map_width => MAP_WIDTH,
      map_height => MAP_HEIGHT,
    );
  })->name('dashboard');
  $self->routes->get('/api/dashboard' => sub {
    my $c = shift;
    my $state = $c->dashboard_state;
    $c->res->headers->cache_control('no-store');
    $c->render(json => {
      snapshot => $c->render_to_string(template => 'snapshot', latest => $state->{latest})->to_string,
      history_rows => $c->render_to_string(template => 'history_rows', observations => $state->{observations})->to_string,
      map_overlay => $c->render_to_string(template => 'map_overlay', overlay => $state->{overlay})->to_string,
      map_description => $state->{map_description},
      next_before => $state->{next_before},
    });
  })->name('dashboard_data');
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
    my $page = $c->history_page($limit, $before);
    if (($c->param('view') // '') eq 'html') {
      return $c->render(json => {
        history_rows => $c->render_to_string(template => 'history_rows', observations => $page->{observations})->to_string,
        next_before => $page->{next_before},
      });
    }
    $c->render(json => $page);
  })->name('history_data');
  $self->routes->get('/api/track' => sub {
    my $c = shift;
    $c->render(json => {points => $c->track_points});
  });
}

1;
