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

done_testing;
