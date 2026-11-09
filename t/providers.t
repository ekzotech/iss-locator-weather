use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ISSTracker::Providers;
use Test::More;
use Mojolicious;
use Test::Mojo;

my $providers = ISSTracker::Providers->new;
my $ua = $providers->ua;
is $ua->connect_timeout, 5, 'connect timeout is bounded';
is $ua->inactivity_timeout, 8, 'inactivity timeout is bounded';
is $ua->request_timeout, 12, 'total request timeout is bounded';

my $mock = Mojolicious->new;
my $position = {message => 'success', timestamp => 100, iss_position => {latitude => '45', longitude => '20'}};
$mock->routes->get('/iss' => sub { shift->render(json => $position) });
my $http = Test::Mojo->new($mock);
$providers->ua($http->ua)->iss_url('/iss');
my ($result, $error);
$providers->iss_position_p->then(sub { $result = shift }, sub { $error = shift })->wait;
is $error, undef, 'local ISS request succeeds';
is_deeply $result, $position, 'ISS JSON arrives through the asynchronous HTTP client';

done_testing;
