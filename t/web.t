use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";
use ISSTrackerTest 'new_tracker';
use Test::More;

my $dir;
my $web;
($web, $dir) = new_tracker();
my $store = $web->app->store;

$web->get_ok('/api/latest')->status_is(200)->json_is({observation => undef});
$store->record({observed_at => 1704067260, latitude => 48.85, longitude => 2.35, weather_status => 'unavailable'});
$web->get_ok('/api/latest')->status_is(200)
  ->json_is('/observation/observed_at', 1704067260)
  ->json_is('/observation/latitude', 48.85)
  ->json_is('/observation/longitude', 2.35);

$store->record({observed_at => 1704067200, latitude => 48.7, longitude => 2.1, weather_status => 'unavailable'});
$web->get_ok('/api/history?limit=1')->status_is(200)
  ->json_is('/observations/0/observed_at', 1704067260)->json_is('/next_before', 1704067260);
$web->get_ok('/api/history?limit=1&before=1704067260')->status_is(200)
  ->json_is('/observations/0/observed_at', 1704067200)->json_is('/next_before', undef);
for my $query ('limit=-1', 'limit=0', 'limit=101', 'limit=1.5', 'before=tomorrow', 'before=253402300800') {
  $web->get_ok("/api/history?$query")->status_is(400)->json_has('/error');
}

done_testing;
