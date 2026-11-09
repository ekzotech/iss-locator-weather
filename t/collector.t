use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";
use ISSTrackerTest qw(new_mock_tracker await_p);
use Test::More;

my $dir;
my ($tracker, $state);
($tracker, $dir, $state) = new_mock_tracker();
my $app = $tracker->app;
my ($inserted, $error) = await_p($app->collector->collect_p);
is $error, undef, 'one collection cycle succeeds';
is $inserted, 1, 'one observation is inserted';
is_deeply $app->store->latest, {
  observed_at => 1704067260, latitude => 48.85, longitude => 2.35,
  weather_status => 'unavailable', temperature_c => undef, cloud_cover => undef,
  weather_code => undef, weather_at => undef,
}, 'mock ISS response is persisted in SQLite';

$state->{iss}{timestamp} += 60;
$state->{iss}{iss_position} = {latitude => 0, longitude => -30};
($inserted, $error) = await_p($app->collector->collect_p);
is $error, undef, 'collection succeeds over water';
is $app->store->latest->{weather_status}, 'water', 'the ocean position is recorded';
is $state->{weather_requests}, 0, 'the water cycle skips the weather endpoint';

done_testing;
