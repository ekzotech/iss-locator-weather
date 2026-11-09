use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";
use ISSTrackerTest 'new_tracker';
use Test::More;

my $dir;
my $web;
($web, $dir) = new_tracker();
my $store = $web->app->store;

$web->get_ok('/')->status_is(200)
  ->element_exists('html[lang="ru"]')
  ->element_exists('meta[name="viewport"]')
  ->text_is('main h1', 'Погода под МКС')
  ->element_exists('body > footer');

$web->get_ok('/api/latest')->status_is(200)->json_is({observation => undef});
$web->get_ok('/api/track')->status_is(200)->json_is({points => []});
$store->record({observed_at => 1704067260, latitude => 48.85, longitude => 2.35, weather_status => 'unavailable'});
$web->get_ok('/')->status_is(200)
  ->text_is('#snapshot h2', 'Последний пролёт')
  ->text_is('.snapshot-coordinates', '48.85°, 2.35°')
  ->element_exists('.snapshot-time[datetime="2024-01-01T00:01:00Z"]');
$web->get_ok('/api/latest')->status_is(200)
  ->json_is('/observation/observed_at', 1704067260)
  ->json_is('/observation/latitude', 48.85)
  ->json_is('/observation/longitude', 2.35)
  ->json_is('/observation/display/observed_iso', '2024-01-01T00:01:00Z')
  ->json_is('/observation/display/status', 'Погода недоступна');

$store->record({observed_at => 1704067200, latitude => 48.7, longitude => 2.1, weather_status => 'unavailable'});
$web->get_ok('/api/history?limit=1')->status_is(200)
  ->json_is('/observations/0/observed_at', 1704067260)->json_is('/next_before', 1704067260)
  ->json_is('/observations/0/display/observed_iso', '2024-01-01T00:01:00Z')
  ->json_is('/observations/0/display/status', 'Погода недоступна');
$web->get_ok('/api/history?limit=1&before=1704067260')->status_is(200)
  ->json_is('/observations/0/observed_at', 1704067200)->json_is('/next_before', undef);
for my $query ('limit=-1', 'limit=0', 'limit=101', 'limit=1.5', 'before=tomorrow', 'before=253402300800') {
  $web->get_ok("/api/history?$query")->status_is(400)->json_has('/error');
}

$store->record({observed_at => 1704060059, latitude => 0, longitude => -30, weather_status => 'water'});
$store->record({observed_at => 1704060060, latitude => 0, longitude => -29, weather_status => 'water'});
$web->get_ok('/api/track')->status_is(200)->json_is('/points', [
  {observed_at => 1704060060, latitude => 0, longitude => -29},
  {observed_at => 1704067200, latitude => 48.7, longitude => 2.1},
  {observed_at => 1704067260, latitude => 48.85, longitude => 2.35},
]);
$store->record({
  observed_at => 1704067320, latitude => 48.85, longitude => 2.35, weather_status => 'available',
  temperature_c => 0, cloud_cover => 0, weather_code => 0, weather_at => 1704067200,
});
$web->get_ok('/')->status_is(200)
  ->text_is('.snapshot-temperature', '0 °C')
  ->text_is('.snapshot-cloud', '0 %')
  ->text_is('.snapshot-conditions', 'Ясно')
  ->element_exists('.snapshot-metrics time[datetime="2024-01-01T00:00:00Z"]');

done_testing;
