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
my $http = Test::Mojo->new($mock);
$providers->ua($http->ua)->iss_url('/iss');
my ($result, $error);
$providers->iss_position_p->then(sub { $result = shift }, sub { $error = shift })->wait;
is $error, undef, 'local ISS request succeeds';
is_deeply $result, {latitude => -45.5, longitude => 0, observed_at => 100},
  'ISS client normalizes string and numeric coordinates';
eval { $providers->parse_iss({%$position, iss_position => {latitude => true, longitude => 0}}) };
like $@, qr/Invalid ISS coordinates/, 'JSON boolean is not a numeric coordinate';
is_deeply $providers->parse_iss({timestamp => '0', iss_position => {latitude => 90, longitude => -180}}),
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

done_testing;
