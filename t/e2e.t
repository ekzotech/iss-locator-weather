use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";
use ISSTrackerTest qw(new_mock_tracker await_p);
use Test::More;

my $dir;
my ($web, $state);
($web, $dir, $state) = new_mock_tracker();
my $app = $web->app;
$app->log->level('fatal');

subtest 'land pass from HTTP providers to dashboard' => sub {
  my ($inserted, $error) = await_p($app->collector->collect_p);
  is $error, undef, 'mocked land pass succeeds';
  is $inserted, 1, 'collector stores the pass';
  $web->get_ok('/')->status_is(200)
    ->text_is('main h1', 'Погода под МКС')
    ->text_is('#snapshot .snapshot-coordinates', '48.85°, 2.35°')
    ->text_is('#snapshot .snapshot-temperature', '0 °C')
    ->text_is('#snapshot .snapshot-cloud', '25 %')
    ->element_exists('svg .map-marker[cx="364.70"][cy="82.30"]')
    ->text_is('#history .history-row:first-child strong', '0 °C')
    ->element_exists('#history .history-row:first-child time[datetime="2024-01-01T00:01:00Z"]');
};

subtest 'land-to-ocean pass keeps both history rows' => sub {
  $state->{iss}{timestamp} += 60;
  $state->{iss}{iss_position} = {latitude => '47.0', longitude => '-3.2'};
  my ($inserted, $error) = await_p($app->collector->collect_p);
  is $error, undef, 'mocked ocean pass succeeds';
  is $inserted, 1, 'ocean point is stored';
  is $state->{weather_requests}, 1, 'only the land pass requests weather';
  $web->get_ok('/')->status_is(200)
    ->text_is('#snapshot .status--water', 'Над водой')
    ->element_exists_not('#snapshot .snapshot-temperature')
    ->element_count_is('.history-row', 2)
    ->text_is('.history-row:first-child .status--water', 'Над водой')
    ->text_is('.history-row:nth-child(2) .history-weather strong', '0 °C');
};

subtest 'weather outage and recovery are visible as separate passes' => sub {
  $state->{iss}{timestamp} += 60;
  $state->{iss}{iss_position} = {latitude => '43.05', longitude => '-3.50'};
  $state->{weather_status} = 503;
  my ($inserted, $error) = await_p($app->collector->collect_p);
  is $error, undef, 'weather outage does not reject the pass';
  is $inserted, 1, 'coordinates are still stored';
  $web->get_ok('/')->status_is(200)
    ->text_is('#snapshot .status--unavailable', 'Погода недоступна')
    ->element_exists_not('#snapshot .snapshot-temperature');

  $state->{iss}{timestamp} += 60;
  $state->{iss}{iss_position} = {latitude => '39.50', longitude => '-3.30'};
  delete $state->{weather_status};
  $state->{weather}{current}{temperature_2m} = 8.5;
  ($inserted, $error) = await_p($app->collector->collect_p);
  is $error, undef, 'weather provider recovers';
  is $inserted, 1, 'the recovered pass is stored';
  $web->get_ok('/')->status_is(200)
    ->text_is('#snapshot .snapshot-temperature', '8.5 °C')
    ->text_is('.history-row:first-child .status--available', 'Над сушей')
    ->text_is('.history-row:nth-child(2) .status--unavailable', 'Погода недоступна')
    ->element_exists_not('.history-row:nth-child(2) .history-weather');
};

subtest 'the dashboard remains available during a coordinate outage' => sub {
  my $last_timestamp = $state->{iss}{timestamp};
  my $weather_requests = $state->{weather_requests};
  $state->{iss}{timestamp} += 60;
  $state->{iss_status} = 502;
  my ($inserted, $error) = await_p($app->collector->collect_p);
  is $inserted, undef, 'no new pass is inserted';
  like $error, qr/HTTP 502/, 'collector reports the coordinate outage';
  is $state->{weather_requests}, $weather_requests, 'no weather request follows a coordinate outage';
  $web->get_ok('/health')->status_is(200);
  $web->get_ok('/')->status_is(200)
    ->text_is('#snapshot .snapshot-coordinates', '39.50°, -3.30°')
    ->text_is('#snapshot .snapshot-temperature', '8.5 °C')
    ->element_exists('#snapshot[data-observed-at="' . $last_timestamp . '"]')
    ->element_count_is('.history-row', 4);
};

done_testing;
