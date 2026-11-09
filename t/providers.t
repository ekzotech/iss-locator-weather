use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ISSTracker::Providers;
use Test::More;
use Mojolicious;
use Test::Mojo;
use Mojo::JSON 'true';

my $providers = ISSTracker::Providers->new;
my $ua = $providers->ua;
is $ua->connect_timeout, 5, 'connect timeout is bounded';
is $ua->inactivity_timeout, 8, 'inactivity timeout is bounded';
is $ua->request_timeout, 12, 'total request timeout is bounded';

my $mock = Mojolicious->new;
my $position = {message => 'success', timestamp => 100, iss_position => {latitude => '-45.50', longitude => 0}};
$mock->routes->get('/iss' => sub { shift->render(json => $position) });
$mock->routes->get('/iss-error' => sub { shift->render(status => 500, text => 'Internal error') });
$mock->routes->get('/iss-invalid' => sub { shift->render(text => '{') });
$mock->routes->get('/iss-denied' => sub { shift->render(json => {%$position, message => 'failure'}) });
my $weather_query;
my $weather = {current => {temperature_2m => -1.5, cloud_cover => 25, weather_code => 1, time => '1704067200'}};
$mock->routes->get('/weather' => sub {
  my $c = shift;
  $weather_query = $c->req->url->query->to_hash;
  $c->render(json => $weather);
});
my $http = Test::Mojo->new($mock);
$providers->ua($http->ua)->iss_url('/iss');
my ($result, $error);
$providers->iss_position_p->then(sub { $result = shift }, sub { $error = shift })->wait;
is $error, undef, 'local ISS request succeeds';
is_deeply $result, {latitude => -45.5, longitude => 0, observed_at => 100},
  'ISS client normalizes string and numeric coordinates';
eval { $providers->parse_iss({%$position, iss_position => {latitude => true, longitude => 0}}) };
like $@, qr/Invalid ISS coordinates/, 'JSON boolean is not a numeric coordinate';
is_deeply $providers->parse_iss({%$position, timestamp => '0', iss_position => {latitude => 90, longitude => -180}}),
  {observed_at => 0, latitude => 90, longitude => -180}, 'coordinate and timestamp boundaries are accepted';
for my $latitude (91, -91, 'NaN', 'Inf', '1e999') {
  eval { $providers->parse_iss({%$position, iss_position => {latitude => $latitude, longitude => 0}}) };
  like $@, qr/Invalid ISS coordinates/, "invalid latitude $latitude is rejected";
}
eval { $providers->parse_iss({%$position, iss_position => {latitude => 0, longitude => 181}}) };
like $@, qr/Invalid ISS coordinates/, 'invalid longitude is rejected';
for my $timestamp (-1, 0.5, 'Inf', 253402300800, undef) {
  eval { $providers->parse_iss({%$position, timestamp => $timestamp}) };
  like $@, qr/Invalid ISS timestamp/, 'invalid timestamp is rejected';
}

for my $case (
  ['/iss-error', qr/HTTP 500/],
  ['/iss-invalid', qr/invalid JSON/],
  ['/iss-denied', qr/did not report success/],
) {
  my ($url, $expected) = @$case;
  $error = undef;
  $providers->iss_url($url)->iss_position_p->catch(sub { $error = shift })->wait;
  like $error, $expected, "rejects $url";
}

$result = $error = undef;
$providers->weather_url('/weather')->weather_p(-45.5, 0)
  ->then(sub { $result = shift }, sub { $error = shift })->wait;
is $error, undef, 'local weather request succeeds';
is_deeply $weather_query, {
  latitude => '-45.5', longitude => '0', current => 'temperature_2m,cloud_cover,weather_code',
  temperature_unit => 'celsius', timeformat => 'unixtime', timezone => 'UTC', cell_selection => 'nearest'
}, 'weather request sends the complete point and model parameters';
is_deeply $result, {temperature_c => -1.5, cloud_cover => 25, weather_code => 1, weather_at => 1704067200},
  'current weather and model time are normalized';
is scalar(gmtime($result->{weather_at})), 'Mon Jan  1 00:00:00 2024', 'model time represents the expected UTC instant';
for my $cloud_cover (0, 100) {
  is_deeply $providers->parse_weather({current => {%{$weather->{current}}, temperature_2m => '0',
    cloud_cover => $cloud_cover, weather_code => '0'}}),
    {temperature_c => 0, cloud_cover => $cloud_cover, weather_code => 0, weather_at => 1704067200},
    "accepts clear weather code and $cloud_cover percent cloud cover";
}
eval { $providers->parse_weather({current => {%{$weather->{current}}, time => 1704067200.5}}) };
like $@, qr/Invalid Open-Meteo model time/, 'fractional model time is rejected';
for my $code (undef, -1, 0.5, 100) {
  eval { $providers->parse_weather({current => {%{$weather->{current}}, weather_code => $code}}) };
  like $@, qr/Invalid Open-Meteo weather code/, 'invalid weather code is rejected';
}
for my $cloud_cover (-1, 101) {
  eval { $providers->parse_weather({current => {temperature_2m => 0, cloud_cover => $cloud_cover}}) };
  like $@, qr/Invalid Open-Meteo cloud cover/, "rejects $cloud_cover percent cloud cover";
}
eval { $providers->parse_weather({current => {temperature_2m => 'NaN'}}) };
like $@, qr/Invalid Open-Meteo temperature/, 'nonfinite temperature is rejected';

done_testing;
