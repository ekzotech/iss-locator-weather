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

done_testing;
