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
  weather_status => 'available', temperature_c => 0, cloud_cover => 25,
  weather_code => 1, weather_at => 1704067200,
}, 'ISS position and model weather are persisted with independent timestamps';
is $state->{weather_requests}, 1, 'land cycle fetches weather exactly once';

$state->{iss}{timestamp} += 60;
$state->{iss}{iss_position} = {latitude => 0, longitude => -30};
($inserted, $error) = await_p($app->collector->collect_p);
is $error, undef, 'collection succeeds over water';
is $app->store->latest->{weather_status}, 'water', 'the ocean position is recorded';
is $state->{weather_requests}, 1, 'the water cycle skips the weather endpoint';

$state->{iss}{timestamp} += 60;
$state->{iss}{iss_position} = {latitude => '48.85', longitude => '2.35'};
$state->{weather_status} = 503;
($inserted, $error) = await_p($app->collector->collect_p);
is $error, undef, 'weather failure does not reject the collection cycle';
is $inserted, 1, 'position is still inserted during a weather outage';
is_deeply $app->store->latest, {
  observed_at => 1704067380, latitude => 48.85, longitude => 2.35,
  weather_status => 'unavailable', temperature_c => undef, cloud_cover => undef,
  weather_code => undef, weather_at => undef,
}, 'a failed weather response cannot leave partial model data';

my $last_observation = $app->store->latest;
my $weather_requests = $state->{weather_requests};
$state->{iss}{timestamp} += 60;
$state->{iss_status} = 502;
($inserted, $error) = await_p($app->collector->collect_p);
like $error, qr/HTTP 502/, 'a coordinate outage rejects the cycle';
is $state->{weather_requests}, $weather_requests, 'coordinate outage skips weather';
is_deeply $app->store->latest, $last_observation, 'latest saved position survives a coordinate outage';

done_testing;
